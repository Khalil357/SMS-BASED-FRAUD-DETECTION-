package com.example.smsfraud.sms;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface SmsRepository extends JpaRepository<Sms, UUID> {
    Sms findBySmsId(UUID smsId);
    Sms findBySenderPhoneNumber(String senderPhoneNumber);
    Sms findByDeviceSmsId(String deviceSmsId);
    Sms findByMessageBody(String messageBody);
    Sms findByReceivedAt(java.time.Instant receivedAt);
    //Sms findByUser(User user);
}
