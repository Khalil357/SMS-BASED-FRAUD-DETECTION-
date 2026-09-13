UPDATE sms_scans SET verdict = 'SCAM' WHERE verdict = 'FRAUD';
UPDATE sms_scans SET verdict = 'TRUST' WHERE verdict = 'SAFE';

CREATE TABLE sms_report_attempts (
    report_attempt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id UUID NOT NULL REFERENCES sms_scans(scan_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    recipient VARCHAR(20) NOT NULL,
    message_body TEXT NOT NULL,
    status VARCHAR(30) NOT NULL,
    prepared_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sms_report_attempts_scan_id ON sms_report_attempts(scan_id);
CREATE INDEX idx_sms_report_attempts_user_id ON sms_report_attempts(user_id);
