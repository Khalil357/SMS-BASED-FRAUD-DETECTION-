package com.example.smsfraud.scan;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

/**
 * An audit record that report instructions were prepared for the user. It does
 * not indicate that an SMS was sent or that the external recipient accepted it.
 */
@Entity
@Table(name = "sms_report_attempts")
public class SmsReportAttempt {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "report_attempt_id")
    private UUID reportAttemptId;

    @Column(name = "scan_id", nullable = false)
    private UUID scanId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private String recipient;

    @Column(name = "message_body", nullable = false)
    private String messageBody;

    /** PREPARED means the client may open its SMS composer; it is not sent. */
    @Column(nullable = false)
    private String status;

    @Column(name = "prepared_at", nullable = false, updatable = false)
    private Instant preparedAt = Instant.now();

    public UUID getReportAttemptId() { return reportAttemptId; }
    public void setReportAttemptId(UUID reportAttemptId) { this.reportAttemptId = reportAttemptId; }
    public UUID getScanId() { return scanId; }
    public void setScanId(UUID scanId) { this.scanId = scanId; }
    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }
    public String getRecipient() { return recipient; }
    public void setRecipient(String recipient) { this.recipient = recipient; }
    public String getMessageBody() { return messageBody; }
    public void setMessageBody(String messageBody) { this.messageBody = messageBody; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Instant getPreparedAt() { return preparedAt; }
    public void setPreparedAt(Instant preparedAt) { this.preparedAt = preparedAt; }
}
