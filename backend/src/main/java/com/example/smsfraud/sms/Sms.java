package com.example.smsfraud.sms;

import com.example.smsfraud.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "sms")
@Getter
@Setter
public class Sms {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "sms_id")
    private UUID smsId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "sender_phone_number", nullable = false, length = 20)
    private String senderPhoneNumber;

    @Column(name = "message_body", nullable = false, columnDefinition = "TEXT")
    private String messageBody;

    @Column(name = "received_at", nullable = false)
    private Instant receivedAt;

    @Column(name = "device_sms_id", length = 255)
    private String deviceSmsId;
}
