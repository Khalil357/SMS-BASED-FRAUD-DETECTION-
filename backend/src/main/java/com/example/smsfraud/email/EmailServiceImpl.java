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
    private final String webUrl;

    public EmailServiceImpl(@Value("${resend.api-key:}") String apiKey,
                            @Value("${email.from:noreply@smsfraud.com}") String fromEmail,
                            @Value("${app.name:SMS Fraud Detection}") String appName,
                            @Value("${app.web-url:https://d2wma51qvc2c0y.cloudfront.net/}") String webUrl) {
        this.resend = new Resend(apiKey);
        this.fromEmail = fromEmail;
        this.appName = appName;
        this.webUrl = webUrl;
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

    @Override
    public void sendWelcomeEmail(String toEmail, String fullName, String role, String initialPassword) {
        try {
            SendEmailRequest request = SendEmailRequest.builder()
                    .from(fromEmail)
                    .to(toEmail)
                    .subject("Welcome to " + appName)
                    .text("Hello " + (fullName == null || fullName.isBlank() ? "" : fullName + ", ") + "\n\n"
                            + "An administrator has created an account for you on " + appName
                            + " with the role " + role + ".\n\n"
                            + "Your login details:\n"
                            + "Email: " + toEmail + "\n"
                            + "Initial password: " + initialPassword + "\n\n"
                            + "Sign in to the Argus Admin Portal here:\n" + webUrl.trim() + "\n\n"
                            + "The first time you sign in, you will verify this email with a one-time code.\n\n"
                            + "Keep this email private. Do not forward or share your password.\n\n"
                            + "If you did not expect this, please contact your administrator.")
                    .build();
            resend.emails().send(request);
        } catch (Exception e) {
            // Provider exceptions may contain the email body, including the password.
            log.warn("Could not email welcome message to {} ({})", toEmail, e.getClass().getSimpleName());
        }
    }

    @Override
    public void sendAccountUpdatedEmail(String toEmail, String fullName) {
        try {
            SendEmailRequest request = SendEmailRequest.builder()
                    .from(fromEmail)
                    .to(toEmail)
                    .subject("Your " + appName + " account was updated")
                    .text("Hello " + (fullName == null || fullName.isBlank() ? "" : fullName + ", ") + "\n\n"
                            + "An administrator has updated your account on " + appName + ".\n\n"
                            + "Please sign in to review your details. If you did not expect this change, "
                            + "please contact your administrator.")
                    .build();
            resend.emails().send(request);
        } catch (Exception e) {
            log.warn("Could not email account-update message to {}: {}", toEmail, e.getMessage());
        }
    }
}
