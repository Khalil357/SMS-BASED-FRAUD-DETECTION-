package com.example.smsfraud.email;

import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

/**
 * SMTP-backed {@link EmailService}. Uses Spring's auto-configured {@link JavaMailSender}
 * (spring-boot-starter-mail) rather than a vendor SDK. Failures are logged, never thrown,
 * so the auth flow never breaks on a mail hiccup.
 */
@Service
@ConditionalOnProperty(name = "email.provider", havingValue = "smtp", matchIfMissing = true)
public class SmtpEmailService implements EmailService {

    private static final Logger log = LoggerFactory.getLogger(SmtpEmailService.class);

    private final JavaMailSender mailSender;
    private final String fromEmail;
    private final String appName;

    public SmtpEmailService(JavaMailSender mailSender,
                            @Value("${email.from:noreply@smsfraud.com}") String fromEmail,
                            @Value("${app.name:SMS Fraud Detection}") String appName) {
        this.mailSender = mailSender;
        this.fromEmail = fromEmail;
        this.appName = appName;
    }

    @Override
    public void sendVerificationCode(String toEmail, String code) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, false, "UTF-8");
            helper.setFrom(fromEmail);
            helper.setTo(toEmail);
            helper.setSubject(appName + " - Verification Code");
            helper.setText(
                "Your verification code is " + code
                    + ". Do not share this code with anyone. It expires in 5 minutes.",
                false // plain text, better deliverability than HTML for OTP
            );
            mailSender.send(message);
            log.info("Verification code emailed to {}", toEmail);
        } catch (Exception e) {
            log.warn("Could not email verification code to {}: {}", toEmail, e.getMessage());
        }
    }
}
