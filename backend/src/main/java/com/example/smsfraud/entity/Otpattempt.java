package com.example.smsfraud.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "otp_attempts")
public class Otpattempt {

    @Id
    @GeneratedValue
    @Column(name = "attempt_id", nullable = false, updatable = false)
    private UUID attemptId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "otp_id", nullable = false)
    private Otpcode otpCode;

    @Column(name = "attempt_count", nullable = false)
    private int attemptCount = 0;

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public OtpAttempt() {
    }

    @PrePersist
    protected void onCreate() {
        createdAt = OffsetDateTime.now();
    }

    public UUID getAttemptId() {
        return attemptId;
    }

    public void setAttemptId(UUID attemptId) {
        this.attemptId = attemptId;
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public Otpcode getOtpCode() {
        return otpCode;
    }

    public void setOtpCode(Otpcode otpCode) {
        this.otpCode = otpCode;
    }

    public int getAttemptCount() {
        return attemptCount;
    }

    public void setAttemptCount(int attemptCount) {
        this.attemptCount = attemptCount;
    }

    public OffsetDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(OffsetDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }
}