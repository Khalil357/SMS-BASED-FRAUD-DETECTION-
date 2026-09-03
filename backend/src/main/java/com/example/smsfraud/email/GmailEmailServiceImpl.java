package com.example.smsfraud.email;

import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Primary;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import java.time.Year;

@Service
@Primary
public class GmailEmailServiceImpl implements EmailService {

    private static final Logger log = LoggerFactory.getLogger(GmailEmailServiceImpl.class);

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;
    private final String fromEmail;
    private final String appName;
    private final String supportEmail;

    public GmailEmailServiceImpl(JavaMailSender mailSender,
                                TemplateEngine templateEngine,
                                @Value("${spring.mail.username:smsfraud.noreply@gmail.com}") String fromEmail,
                                @Value("${app.name:Argus}") String appName,
                                @Value("${email.support:support@smsfraud.com}") String supportEmail) {
        this.mailSender = mailSender;
        this.templateEngine = templateEngine;
        this.fromEmail = fromEmail;
        this.appName = appName;
        this.supportEmail = supportEmail;
    }

    @Override
    public void sendVerificationCode(String toEmail, String code) {
        if (toEmail == null || toEmail.isBlank()) {
            log.warn("Cannot send OTP email: recipient email address is empty.");
            return;
        }

        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            Context context = new Context();
            String userName = toEmail.contains("@") ? toEmail.substring(0, toEmail.indexOf('@')) : toEmail;
            context.setVariable("userName", userName);
            context.setVariable("appName", appName);
            context.setVariable("otp", code);
            context.setVariable("otpExpiryMinutes", 5);
            context.setVariable("year", Year.now().getValue());
            context.setVariable("supportEmail", supportEmail);

            String htmlContent = templateEngine.process("email/otp-email", context);

            helper.setFrom(fromEmail);
            helper.setTo(toEmail);
            helper.setSubject("🔐 " + appName + " - Verification Code");
            helper.setText(htmlContent, true);

            mailSender.send(message);
            log.info("OTP verification email sent successfully via Gmail SMTP to {}", toEmail);
        } catch (Exception e) {
            log.error("Failed to send OTP email to {} via Gmail SMTP. Reason: {}", toEmail, e.getMessage(), e);
        }
    }
}
