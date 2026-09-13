package com.example.smsfraud.sms;

import com.twilio.Twilio;
import com.twilio.rest.api.v2010.account.Message;
import com.twilio.type.PhoneNumber;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(name = "sms.provider", havingValue = "twilio")
public class TwilioSmsServiceImpl implements SmsSenderService {

    private static final Logger log = LoggerFactory.getLogger(TwilioSmsServiceImpl.class);

    private final String accountSid;
    private final String authToken;
    private final String fromPhoneNumber;

    public TwilioSmsServiceImpl(@Value("${twilio.account-sid:}") String accountSid,
                                @Value("${twilio.auth-token:}") String authToken,
                                @Value("${twilio.phone-number:}") String fromPhoneNumber) {
        this.accountSid = accountSid;
        this.authToken = authToken;
        this.fromPhoneNumber = fromPhoneNumber;
    }

    @PostConstruct
    public void init() {
        if (accountSid != null && !accountSid.isBlank() && authToken != null && !authToken.isBlank()) {
            Twilio.init(accountSid, authToken);
            log.info("Twilio initialized with Account SID: {}", accountSid);
        } else {
            log.warn("Twilio credentials are not set. SMS sending will fail.");
        }
    }

    @Override
    public void sendSms(String toPhoneNumber, String messageText) {
        if (accountSid == null || accountSid.isBlank() || authToken == null || authToken.isBlank()) {
            log.warn("Cannot send SMS: Twilio credentials are not configured.");
            return;
        }

        try {
            Message message = Message.creator(
                    new PhoneNumber(toPhoneNumber),
                    new PhoneNumber(fromPhoneNumber),
                    messageText
            ).create();
            log.info("SMS sent successfully to {}. Twilio Message SID: {}", toPhoneNumber, message.getSid());
        } catch (Exception e) {
            log.error("Failed to send SMS to {}: {}", toPhoneNumber, e.getMessage());
        }
    }
}
