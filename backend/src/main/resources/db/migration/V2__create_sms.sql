CREATE TABLE sms (
    sms_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    sender_phone_number  VARCHAR(20) NOT NULL,
    message_body         TEXT NOT NULL,
    received_at          TIMESTAMPTZ NOT NULL,
    device_sms_id        VARCHAR(255)
);

CREATE INDEX idx_sms_user_id ON sms(user_id);
