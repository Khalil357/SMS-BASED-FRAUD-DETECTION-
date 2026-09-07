CREATE TABLE sms_scans (
    scan_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    sender        VARCHAR(255),
    message_body  TEXT NOT NULL,
    verdict       VARCHAR(50) NOT NULL,
    confidence    DOUBLE PRECISION,
    source        VARCHAR(50) NOT NULL DEFAULT 'MANUAL_QUERY',
    scanned_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sms_scans_user_scanned
    ON sms_scans (user_id, scanned_at DESC);
