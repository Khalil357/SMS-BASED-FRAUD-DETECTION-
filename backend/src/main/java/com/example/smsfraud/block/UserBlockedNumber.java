package com.example.smsfraud.block;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_blocked_numbers")
public class UserBlockedNumber {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "block_id")
    private UUID blockId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "phone_number", nullable = false)
    private String phoneNumber;

    private String reason;

    @Column(name = "blocked_at", nullable = false, updatable = false)
    private Instant blockedAt = Instant.now();

    public UserBlockedNumber() {}

    public UUID getBlockId() {
        return blockId;
    }

    public void setBlockId(UUID blockId) {
        this.blockId = blockId;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public String getPhoneNumber() {
        return phoneNumber;
    }

    public void setPhoneNumber(String phoneNumber) {
        this.phoneNumber = phoneNumber;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public Instant getBlockedAt() {
        return blockedAt;
    }

    public void setBlockedAt(Instant blockedAt) {
        this.blockedAt = blockedAt;
    }
}
