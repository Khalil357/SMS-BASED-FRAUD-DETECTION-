package com.example.smsfraud.sender;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "blocked_senders")
public class BlockedSender {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "blocked_sender_id")
    private UUID blockedSenderId;

    @Column(name = "phone_number", nullable = false, unique = true)
    private String phoneNumber;

    private String reason;

    @Column(name = "blocked_at", nullable = false, updatable = false)
    private Instant blockedAt = Instant.now();

    public UUID getBlockedSenderId() {
        return blockedSenderId;
    }

    public void setBlockedSenderId(UUID blockedSenderId) {
        this.blockedSenderId = blockedSenderId;
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
