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
    private final String webUrl;

    public SmtpEmailService(JavaMailSender mailSender,
                            @Value("${email.from:noreply@smsfraud.com}") String fromEmail,
                            @Value("${app.name:SMS Fraud Detection}") String appName,
                            @Value("${app.web-url:https://d2wma51qvc2c0y.cloudfront.net/}") String webUrl) {
        this.mailSender = mailSender;
        this.fromEmail = fromEmail;
        this.appName = appName;
        this.webUrl = webUrl;
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

    @Override
    public void sendWelcomeEmail(String toEmail, String fullName, String role, String initialPassword) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, false, "UTF-8");
            helper.setFrom(fromEmail);
            helper.setTo(toEmail);
            helper.setSubject("Welcome to " + appName);
            helper.setText(
                "Hello " + (fullName == null || fullName.isBlank() ? "" : fullName + ", ") + "\n\n"
                    + "An administrator has created an account for you on " + appName
                    + " with the role " + role + ".\n\n"
                    + "Your login details:\n"
                    + "Email: " + toEmail + "\n"
                    + "Initial password: " + initialPassword + "\n\n"
                    + "Sign in to the Argus Admin Portal here:\n" + webUrl.trim() + "\n\n"
                    + "The first time you sign in, you will verify this email with a one-time code.\n\n"
                    + "Keep this email private. Do not forward or share your password.\n\n"
                    + "If you did not expect this, please contact your administrator.",
                false
            );
            mailSender.send(message);
            log.info("Welcome email sent to {}", toEmail);
        } catch (Exception e) {
            // Provider exceptions may contain the email body, including the password.
            log.warn("Could not email welcome message to {} ({})", toEmail, e.getClass().getSimpleName());
        }
    }

    @Override
    public void sendAccountUpdatedEmail(String toEmail, String fullName) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, false, "UTF-8");
            helper.setFrom(fromEmail);
            helper.setTo(toEmail);
            helper.setSubject("Your " + appName + " account was updated");
            helper.setText(
                "Hello " + (fullName == null || fullName.isBlank() ? "" : fullName + ", ") + "\n\n"
                    + "An administrator has updated your account on " + appName + ".\n\n"
                    + "Please sign in to review your details. If you did not expect this change, "
                    + "please contact your administrator.",
                false
            );
            mailSender.send(message);
            log.info("Account-updated email sent to {}", toEmail);
        } catch (Exception e) {
            log.warn("Could not email account-update message to {}: {}", toEmail, e.getMessage());
        }
    }
}
