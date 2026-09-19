CREATE TABLE blocked_senders (
    blocked_sender_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number      VARCHAR(255) UNIQUE NOT NULL,
    reason            VARCHAR(255),
    blocked_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
