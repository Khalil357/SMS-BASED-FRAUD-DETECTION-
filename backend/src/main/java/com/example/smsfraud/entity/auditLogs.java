package com.example.smsfraud.entity;
import com.yourorg.frauddetect.user.User;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "audit_logs")
public class auditLogs {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "log_id")
    private UUID logId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(name = "event_type", nullable = false)
    private String eventType;

    @Column(nullable = false)
    private String status;

    @Column(name = "ip_address")
    private String ipAddress;

    @Column(name = "device_id")
    private String deviceId;

    @Column(columnDefinition = "TEXT")
    private String details;

    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    // getters and setters

    public UUID getLogId() { return logId; }
    public void setLogId(UUID logId) { this.logId = logId; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public String getEventType() { return eventType; }
    public void setEventType(String eventType) { this.eventType = eventType; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }

    public String getDeviceId() { return deviceId; }
    public void setDeviceId(String deviceId) { this.deviceId = deviceId; }

    public String getDetails() { return details; }
    public void setDetails(String details) { this.details = details; }

    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }

    public Instant getCreatedAt() { return createdAt; }
}