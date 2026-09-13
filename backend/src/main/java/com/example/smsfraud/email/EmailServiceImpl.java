package com.example.smsfraud.email;

import com.resend.Resend;
import com.resend.services.emails.model.SendEmailRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(name = "email.provider", havingValue = "resend")
public class EmailServiceImpl implements EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailServiceImpl.class);

    private final Resend resend;
    private final String fromEmail;
    private final String appName;

    public EmailServiceImpl(@Value("${resend.api-key:}") String apiKey,
                            @Value("${email.from:noreply@smsfraud.com}") String fromEmail,
                            @Value("${app.name:SMS Fraud Detection}") String appName) {
        this.resend = new Resend(apiKey);
        this.fromEmail = fromEmail;
        this.appName = appName;
    }

    @Override
    public void sendVerificationCode(String toEmail, String code) {
        try {
            SendEmailRequest request = SendEmailRequest.builder()
                    .from(fromEmail)
                    .to(toEmail)
                    .subject("🔐 " + appName + " - Verification Code")
                    .text("Your verification code is " + code + ".")
                    .build();
            resend.emails().send(request);
        } catch (Exception e) {
            log.warn("Could not email verification code to {}: {}", toEmail, e.getMessage());
        }
    }
}
