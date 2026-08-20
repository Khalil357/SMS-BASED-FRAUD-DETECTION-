package com.example.smsfraud.config;

import com.example.smsfraud.entity.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import jakarta.mail.internet.MimeMessage;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

/**
 * Email Service - Handles all email communications
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;

    @Value("${email.from}")
    private String fromEmail;

    @Value("${app.name:SMS Fraud Detection}")
    private String appName;

    @Value("${app.url:http://localhost:8080}")
    private String appUrl;

    @Value("${email.support}")
    private String supportEmail;

    /**
     * Send OTP verification email
     */
    public void sendOtpEmail(User user, String otp) {
        log.info("Sending OTP email to: {}", user.getEmail());
        
        try {
            Map<String, Object> model = new HashMap<>();
            model.put("userName", user.getName());
            model.put("otp", otp);
            model.put("otpExpiryMinutes", 5);
            model.put("appName", appName);
            model.put("supportEmail", supportEmail);
            model.put("year", LocalDateTime.now().getYear());

            String html = renderTemplate("email/otp-email", model);
            sendHtmlEmail(user.getEmail(), "🔐 " + appName + " - Email Verification", html);
            
            log.info("OTP email sent to: {}", user.getEmail());
        } catch (Exception e) {
            log.error("Failed to send OTP email to {}: {}", user.getEmail(), e.getMessage());
            throw new BusinessException("Failed to send verification email. Please try again.");
        }
    }

    /**
     * Send password reset email
     */
    public void sendPasswordResetEmail(User user, String otp) {
        log.info("Sending password reset email to: {}", user.getEmail());
        
        try {
            Map<String, Object> model = new HashMap<>();
            model.put("userName", user.getName());
            model.put("otp", otp);
            model.put("otpExpiryMinutes", 5);
            model.put("appName", appName);
            model.put("appUrl", appUrl);
            model.put("supportEmail", supportEmail);
            model.put("year", LocalDateTime.now().getYear());

            String html = renderTemplate("email/password-reset-email", model);
            sendHtmlEmail(user.getEmail(), "🔐 " + appName + " - Password Reset Request", html);
            
            log.info("Password reset email sent to: {}", user.getEmail());
        } catch (Exception e) {
            log.error("Failed to send password reset email: {}", e.getMessage());
            throw new BusinessException("Failed to send password reset email. Please try again.");
        }
    }

    /**
     * Send welcome email
     */
    public void sendWelcomeEmail(User user) {
        log.info("Sending welcome email to: {}", user.getEmail());
        
        try {
            Map<String, Object> model = new HashMap<>();
            model.put("userName", user.getName());
            model.put("appName", appName);
            model.put("appUrl", appUrl);
            model.put("supportEmail", supportEmail);
            model.put("year", LocalDateTime.now().getYear());
            model.put("registrationDate", 
                user.getCreatedAt().format(DateTimeFormatter.ofPattern("MMMM d, yyyy")));

            String html = renderTemplate("email/welcome-email", model);
            sendHtmlEmail(user.getEmail(), "🎉 Welcome to " + appName + "!", html);
            
            log.info("Welcome email sent to: {}", user.getEmail());
        } catch (Exception e) {
            log.error("Failed to send welcome email: {}", e.getMessage());
            // Non-critical - don't throw
        }
    }

    /**
     * Send account locked notification
     */
    public void sendAccountLockedEmail(User user) {
        log.info("Sending account locked email to: {}", user.getEmail());
        
        try {
            Map<String, Object> model = new HashMap<>();
            model.put("userName", user.getName());
            model.put("appName", appName);
            model.put("appUrl", appUrl);
            model.put("supportEmail", supportEmail);
            model.put("lockedAt", user.getLockedAt());
            model.put("year", LocalDateTime.now().getYear());

            String html = renderTemplate("email/account-locked-email", model);
            sendHtmlEmail(user.getEmail(), "⚠️ " + appName + " - Account Locked", html);
            
            log.info("Account locked email sent to: {}", user.getEmail());
        } catch (Exception e) {
            log.error("Failed to send account locked email: {}", e.getMessage());
            // Non-critical - don't throw
        }
    }

    /**
     * Send login alert email
     */
    public void sendLoginAlertEmail(User user, String ipAddress, String userAgent, String location) {
        log.info("Sending login alert email to: {}", user.getEmail());
        
        try {
            Map<String, Object> model = new HashMap<>();
            model.put("userName", user.getName());
            model.put("appName", appName);
            model.put("ipAddress", ipAddress);
            model.put("userAgent", userAgent);
            model.put("location", location);
            model.put("timestamp", LocalDateTime.now());
            model.put("supportEmail", supportEmail);
            model.put("year", LocalDateTime.now().getYear());

            String html = renderTemplate("email/login-alert-email", model);
            sendHtmlEmail(user.getEmail(), "🔔 " + appName + " - New Login Detected", html);
            
            log.info("Login alert email sent to: {}", user.getEmail());
        } catch (Exception e) {
            log.error("Failed to send login alert email: {}", e.getMessage());
            // Non-critical - don't throw
        }
    }

    /**
     * Send HTML email
     */
    private void sendHtmlEmail(String to, String subject, String htmlBody) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(fromEmail);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(htmlBody, true);
            mailSender.send(message);
        } catch (Exception e) {
            log.error("Failed to send email to {}: {}", to, e.getMessage());
            throw new RuntimeException("Failed to send email", e);
        }
    }

    /**
     * Render Thymeleaf template
     */
    private String renderTemplate(String template, Map<String, Object> model) {
        Context context = new Context();
        context.setVariables(model);
        return templateEngine.process(template, context);
    }
}