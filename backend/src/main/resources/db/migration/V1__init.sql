-- Roles
CREATE TABLE user_roles (
    role_id   SERIAL PRIMARY KEY,
    role_name VARCHAR(50) UNIQUE NOT NULL
);

INSERT INTO user_roles (role_name) VALUES ('ADMIN'), ('USER');

-- Users
CREATE TABLE users (
    user_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email                 VARCHAR(255) UNIQUE,
    phone                 VARCHAR(20) UNIQUE,
    full_name             VARCHAR(255),
    password_hash         VARCHAR(255),
    gender                VARCHAR(20),
    role_id               INT NOT NULL REFERENCES user_roles(role_id),
    is_verified           BOOLEAN NOT NULL DEFAULT FALSE,
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    is_locked             BOOLEAN NOT NULL DEFAULT FALSE,
    failed_login_attempts INT NOT NULL DEFAULT 0,
    last_login_at         TIMESTAMPTZ,
    locked_at             TIMESTAMPTZ,
    token_version         INT NOT NULL DEFAULT 0,
    google_id             VARCHAR(255) UNIQUE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
