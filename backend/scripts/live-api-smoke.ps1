param(
    [Parameter(Mandatory = $true)]
    [string]$SshKey,

    [string]$BaseUrl = "https://54.242.107.64",
    [string]$SshHost = "ec2-user@54.242.107.64"
)

$ErrorActionPreference = "Stop"
$results = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[string]]::new()
$runId = (Get-Date -Format "yyyyMMddHHmmss") + ([guid]::NewGuid().ToString("N").Substring(0, 6))
$email = "api-integrity-$runId@example.invalid"
$foreignEmail = "api-integrity-foreign-$runId@example.invalid"
$phone = "+255000" + $runId.Substring($runId.Length - 6)
$password = "Live!" + [guid]::NewGuid().ToString("N") + "9a"
$registered = $false

function Add-Result {
    param([string]$Name, [string]$Result, [string]$Detail = "")
    $script:results.Add([pscustomobject]@{ Test = $Name; Result = $Result; Detail = $Detail })
    if ($Result -eq "FAIL") {
        $script:failures.Add($Name)
    }
}

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [string]$Token = ""
    )

    $headers = @{}
    if ($Token) {
        $headers.Authorization = "Bearer $Token"
    }
    $arguments = @{
        Uri = "$BaseUrl$Path"
        Method = $Method
        Headers = $headers
        SkipHttpErrorCheck = $true
        TimeoutSec = 90
    }
    if ($null -ne $Body) {
        $arguments.ContentType = "application/json"
        $arguments.Body = ($Body | ConvertTo-Json -Compress -Depth 8)
    }

    $response = Invoke-WebRequest @arguments
    $json = $null
    if ($response.Content) {
        try { $json = $response.Content | ConvertFrom-Json -Depth 20 } catch { }
    }
    [pscustomobject]@{
        Status = [int]$response.StatusCode
        Json = $json
    }
}

function Expect-Status {
    param([string]$Name, [object]$Response, [int[]]$Expected)
    if ($Expected -contains $Response.Status) {
        Add-Result $Name "PASS" "HTTP $($Response.Status)"
        return $true
    }
    Add-Result $Name "FAIL" "Expected $($Expected -join '/') but received HTTP $($Response.Status)"
    return $false
}

function Invoke-Ssh {
    param([string]$Command)
    $output = & ssh -i $SshKey -o BatchMode=yes -o ConnectTimeout=15 $SshHost $Command
    if ($LASTEXITCODE -ne 0) {
        throw "SSH command failed with exit code $LASTEXITCODE"
    }
    ($output -join "`n").Trim()
}

try {
    Expect-Status "Public health" (Invoke-Api GET "/actuator/health") @(200) | Out-Null
    Expect-Status "Root hidden" (Invoke-Api GET "/") @(404) | Out-Null
    Expect-Status "Swagger hidden" (Invoke-Api GET "/swagger-ui/index.html") @(404) | Out-Null
    Expect-Status "Protected route rejects anonymous client" (Invoke-Api GET "/api/users/me") @(401) | Out-Null

    $infrastructure = Invoke-Ssh 'cd /home/ec2-user/sms-fraud-backend; sudo docker compose exec -T db pg_isready -U sms_app -d sms_fraud >/dev/null && echo DB_READY; sudo docker compose exec -T redis sh -c ''REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping'' | grep -q PONG && echo REDIS_READY'
    if ($infrastructure -match 'DB_READY') {
        Add-Result "PostgreSQL connection" "PASS" "Database accepts connections"
    } else {
        Add-Result "PostgreSQL connection" "FAIL" "Database readiness check failed"
    }
    if ($infrastructure -match 'REDIS_READY') {
        Add-Result "Redis connection" "PASS" "Redis authenticated ping succeeded"
    } else {
        Add-Result "Redis connection" "FAIL" "Redis authenticated ping failed"
    }

    $register = Invoke-Api POST "/api/auth/register" @{
        full_name = "API Integrity Test"
        email = $email
        phone_number = $phone
        gender = "OTHER"
        password = $password
    }
    if (Expect-Status "Registration" $register @(201)) {
        $registered = $true
        if ($null -ne $register.Json.data.otp -and [string]$register.Json.data.otp -ne "") {
            Add-Result "Registration response secrecy" "FAIL" "OTP is exposed in the API response"
        } else {
            Add-Result "Registration response secrecy" "PASS" "OTP is not returned"
        }
    }

    if (-not $registered) {
        throw "Registration did not complete"
    }

    $login = Invoke-Api POST "/api/auth/login" @{
        email = $email
        password = $password
    }
    Expect-Status "Credential login starts OTP challenge" $login @(200) | Out-Null

    $otpCommand = 'cd /home/ec2-user/sms-fraud-backend; sudo docker compose exec -T redis sh -c ''REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli --raw GET "smsfraud:otp:{0}"''' -f $email
    $otp = Invoke-Ssh $otpCommand
    if ($otp -match '^\d{4,8}$') {
        Add-Result "Redis OTP persistence" "PASS" "OTP exists with expected shape"
    } else {
        Add-Result "Redis OTP persistence" "FAIL" "OTP was not found"
        throw "OTP not available"
    }

    $verify = Invoke-Api POST "/api/auth/verify-login-otp" @{
        email = $email
        verificationCode = $otp
    }
    if (-not (Expect-Status "OTP verification and JWT issuance" $verify @(200))) {
        throw "OTP verification failed"
    }

    $accessToken = [string]$verify.Json.data.token
    $refreshToken = [string]$verify.Json.data.refreshToken
    if (-not $accessToken -or -not $refreshToken) {
        Add-Result "JWT response fields" "FAIL" "Access or refresh token missing"
        throw "Token fields missing"
    }
    Add-Result "JWT response fields" "PASS" "Both tokens returned"

    $profile = Invoke-Api GET "/api/users/me" $null $accessToken
    if (Expect-Status "Authenticated profile" $profile @(200)) {
        if ([string]$profile.Json.data.email -eq $email) {
            Add-Result "JWT identity binding" "PASS" "Profile matches authenticated subject"
        } else {
            Add-Result "JWT identity binding" "FAIL" "Profile does not match test subject"
        }
    }

    $insertRecordCommand = "cd /home/ec2-user/sms-fraud-backend; sudo docker compose exec -T db psql -U sms_app -d sms_fraud -tA -c `"INSERT INTO sms_scans (user_id, sender, message_body, verdict, confidence, source, is_scam, scanned_at) SELECT user_id, 'LIVE_DELETE_TEST', 'Synthetic false-positive record', 'FRAUD', 1.0, 'LIVE_API_TEST', true, now() FROM users WHERE email='$email' RETURNING scan_id;`""
    $insertOutput = Invoke-Ssh $insertRecordCommand
    $recordIdMatch = [regex]::Match($insertOutput, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if (-not $recordIdMatch.Success) {
        Add-Result "False-positive record setup" "FAIL" "Could not create synthetic fraud record"
    } else {
        $recordId = $recordIdMatch.Value
        Add-Result "False-positive record setup" "PASS" "Synthetic record persisted"
        $deleteRecord = Invoke-Api DELETE "/api/v1/fraud-records/$recordId" $null $accessToken
        if (Expect-Status "False-positive deletion endpoint" $deleteRecord @(204)) {
            $deleteCheckCommand = "cd /home/ec2-user/sms-fraud-backend; sudo docker compose exec -T db psql -U sms_app -d sms_fraud -tA -c `"SELECT count(*) FROM sms_scans WHERE scan_id='$recordId';`""
            $deleteCount = Invoke-Ssh $deleteCheckCommand
            if ($deleteCount -eq "0") {
                Add-Result "False-positive database deletion" "PASS" "Record is absent from PostgreSQL"
            } else {
                Add-Result "False-positive database deletion" "FAIL" "Record still exists in PostgreSQL"
            }
        }
    }

    $insertForeignCommand = "cd /home/ec2-user/sms-fraud-backend; sudo docker compose exec -T db psql -U sms_app -d sms_fraud -tA -c `"WITH foreign_user AS (INSERT INTO users (email, role_id) SELECT '$foreignEmail', role_id FROM user_roles WHERE role_name='USER' RETURNING user_id) INSERT INTO sms_scans (user_id, sender, message_body, verdict, confidence, source, is_scam, scanned_at) SELECT user_id, 'LIVE_FOREIGN_TEST', 'Synthetic foreign-owned record', 'FRAUD', 1.0, 'LIVE_API_TEST', true, now() FROM foreign_user RETURNING scan_id;`""
    $foreignInsertOutput = Invoke-Ssh $insertForeignCommand
    $foreignRecordIdMatch = [regex]::Match($foreignInsertOutput, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if (-not $foreignRecordIdMatch.Success) {
        Add-Result "Foreign-owned record setup" "FAIL" "Could not create foreign-owned record"
    } else {
        $foreignRecordId = $foreignRecordIdMatch.Value
        Add-Result "Foreign-owned record setup" "PASS" "Foreign record persisted"
        $foreignDelete = Invoke-Api DELETE "/api/v1/fraud-records/$foreignRecordId" $null $accessToken
        if (Expect-Status "Cross-user deletion denied" $foreignDelete @(404)) {
            $foreignCheckCommand = "cd /home/ec2-user/sms-fraud-backend; sudo docker compose exec -T db psql -U sms_app -d sms_fraud -tA -c `"SELECT count(*) FROM sms_scans WHERE scan_id='$foreignRecordId';`""
            $foreignCount = Invoke-Ssh $foreignCheckCommand
            if ($foreignCount -eq "1") {
                Add-Result "Foreign record preserved" "PASS" "Foreign-owned row remains in PostgreSQL"
            } else {
                Add-Result "Foreign record preserved" "FAIL" "Foreign-owned row was removed"
            }
        }
    }

    Expect-Status "USER cannot access admin API" (Invoke-Api GET "/api/admin/stats" $null $accessToken) @(403) | Out-Null
    Expect-Status "Scan history" (Invoke-Api GET "/api/scans?page=0&size=20" $null $accessToken) @(200) | Out-Null
    Expect-Status "Fraud-alert history" (Invoke-Api GET "/api/scans/fraud?page=0&size=20" $null $accessToken) @(200) | Out-Null

    $scan = Invoke-Api POST "/api/scans" @{
        sender = "INTEGRITY_TEST"
        message_body = "Hello, are we still meeting at 3 PM today?"
        source = "LIVE_API_TEST"
    } $accessToken
    Expect-Status "ML-backed SMS scan" $scan @(200, 201) | Out-Null

    $refresh = Invoke-Api POST "/api/auth/refresh" @{ refreshToken = $refreshToken }
    if (Expect-Status "Refresh token" $refresh @(200)) {
        $refreshedAccessToken = [string]$refresh.Json.data.token
        if ($refreshedAccessToken) {
            Expect-Status "Refreshed access token works" (Invoke-Api GET "/api/users/me" $null $refreshedAccessToken) @(200) | Out-Null
        } else {
            Add-Result "Refreshed access token works" "FAIL" "Refresh response did not contain an access token"
        }
    }

    $dbCommand = "cd /home/ec2-user/sms-fraud-backend; sudo docker compose exec -T db psql -U sms_app -d sms_fraud -tA -c `"SELECT count(*) || ':' || bool_and(is_verified) FROM users WHERE email='$email';`""
    $dbCheck = Invoke-Ssh $dbCommand
    if ($dbCheck -eq "1:true") {
        Add-Result "PostgreSQL persistence" "PASS" "User exists and is verified"
    } else {
        Add-Result "PostgreSQL persistence" "FAIL" "Unexpected database state"
    }

    $otpAfterVerify = Invoke-Ssh $otpCommand
    if ([string]::IsNullOrWhiteSpace($otpAfterVerify)) {
        Add-Result "OTP invalidation" "PASS" "Redis key removed after verification"
    } else {
        Add-Result "OTP invalidation" "FAIL" "Redis key remained after verification"
    }

    Expect-Status "Logout" (Invoke-Api POST "/api/auth/logout" @{ refreshToken = $refreshToken }) @(200) | Out-Null
    Expect-Status "Logged-out refresh token rejected" (Invoke-Api POST "/api/auth/refresh" @{ refreshToken = $refreshToken }) @(401) | Out-Null
    Expect-Status "Access token revoked after logout" (Invoke-Api GET "/api/users/me" $null $accessToken) @(401) | Out-Null
}
catch {
    Add-Result "Test execution" "FAIL" $_.Exception.Message
}
finally {
    try {
        $cleanup = "cd /home/ec2-user/sms-fraud-backend; sudo docker compose exec -T redis sh -c 'REDISCLI_AUTH=`"`$REDIS_PASSWORD`" redis-cli DEL `"smsfraud:otp:$email`" `"smsfraud:otp:$phone`" >/dev/null'; sudo docker compose exec -T db psql -U sms_app -d sms_fraud -v ON_ERROR_STOP=1 -c `"DELETE FROM users WHERE email IN ('$email', '$foreignEmail');`" >/dev/null; sudo docker compose exec -T db psql -U sms_app -d sms_fraud -tA -c `"SELECT count(*) FROM users WHERE email IN ('$email', '$foreignEmail');`""
        $remaining = Invoke-Ssh $cleanup
        if ($remaining -eq "0") {
            Add-Result "Synthetic-data cleanup" "PASS" "Test user, dependent rows, and OTP keys removed"
        } else {
            Add-Result "Synthetic-data cleanup" "FAIL" "Synthetic user still exists"
        }
    }
    catch {
        Add-Result "Synthetic-data cleanup" "FAIL" "Cleanup command failed"
    }
}

$results | Format-Table -AutoSize
Write-Output "TOTAL=$($results.Count) PASSED=$(($results | Where-Object Result -eq 'PASS').Count) FAILED=$($failures.Count)"
if ($failures.Count -gt 0) {
    Write-Output ("FAILED_TESTS=" + ($failures -join ", "))
    exit 1
}
