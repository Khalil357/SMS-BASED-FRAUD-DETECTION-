# Run the backend locally (Windows + PostgreSQL)

The backend is already configured for PostgreSQL. Its development connection is:

| Setting | Value |
| --- | --- |
| Host / port | `localhost:5432` |
| Database | `sms_fraud` |
| Application user | `sms_app` |
| Application password | `sms_pass` |

## 1. Start PostgreSQL

PostgreSQL 17 is installed on this machine, but at the time this guide was
added nothing was listening on port `5432`. Start its database service from
Windows **Services** (it is normally named `postgresql-x64-17`), or complete
the PostgreSQL installer so that it creates and starts a database cluster.

Verify it is running:

```powershell
& 'C:\Program Files\PostgreSQL\17\bin\pg_isready.exe' -h localhost -p 5432
```

The expected result is `accepting connections`.

## 2. Create the application role and database

Run these commands in PowerShell. Enter the password you chose for the
PostgreSQL administrator (`postgres`) when prompted.

```powershell
$psql = 'C:\Program Files\PostgreSQL\17\bin\psql.exe'
& $psql -U postgres -d postgres -c "CREATE ROLE sms_app LOGIN PASSWORD 'sms_pass';"
& $psql -U postgres -d postgres -c "CREATE DATABASE sms_fraud OWNER sms_app;"
```

If either command says the role or database already exists, leave it in place
and continue. If you chose another password for `sms_app`, use that same value
in step 3.

Do **not** run the SQL migrations yourself. Flyway runs
`V1__init.sql` and `V2__sms_scans.sql` automatically the first time the backend
starts. `V1` now enables `pgcrypto`, which supplies `gen_random_uuid()` on
PostgreSQL versions that require the extension.

## 3. Set local environment variables

You only need these if your database values differ from the development
defaults. They apply to the current PowerShell window:

```powershell
$env:SPRING_DATASOURCE_URL = 'jdbc:postgresql://localhost:5432/sms_fraud'
$env:SPRING_DATASOURCE_USERNAME = 'sms_app'
$env:SPRING_DATASOURCE_PASSWORD = 'sms_pass'
$env:JWT_SECRET = 'replace-with-a-random-secret-that-is-at-least-32-characters'
```

`SPRING_DATASOURCE_*` is the correct way to override the connection; a `.env`
file is not loaded by this Spring Boot project automatically.

## 4. Install Java and run

This project requires **JDK 21**. `java` was not on this machine's PATH when
this guide was added, so install a JDK 21 and add its `bin` folder to PATH, then
open a new PowerShell window.

```powershell
java -version
cd backend
.\mvnw.cmd spring-boot:run
```

On a successful first startup, the log will show Flyway applying the two
migrations and Spring Boot listening on port `8080`.

SMTP credentials are optional for starting the API. Without them, email sends
are logged as warnings; OTP values are still returned by the API for local
development.
