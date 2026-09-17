package com.example.smsfraud.otp;

import com.example.smsfraud.email.EmailService;
import com.example.smsfraud.sms.SmsSenderService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * Fire-and-forget delivery of one-time codes. Auth endpoints return immediately
 * instead of blocking on external SMTP/SMS providers, which can take seconds or
 * time out (e.g. a gateway 504) — blocking there would stall login/registration.
 * Delivery failures are logged by the underlying services, never surfaced to
 * the caller.
 */
@Component
public class OtpNotifier {

    private static final Logger log = LoggerFactory.getLogger(OtpNotifier.class);

    private static final String DEFAULT_CODE_TEXT =
            "Your verification code is %s. Do not share this code with anyone. It expires in 5 minutes.";

    private final EmailService emailService;
    private final SmsSenderService smsService;
    private final ExecutorService executor;

    public OtpNotifier(EmailService emailService, SmsSenderService smsService) {
        this.emailService = emailService;
        this.smsService = smsService;
        this.executor = Executors.newFixedThreadPool(2, runnable -> {
            Thread thread = new Thread(runnable, "otp-notifier");
            thread.setDaemon(true);
            return thread;
        });
    }

    /** Emails and SMSes a registration/verification code (phone is the OTP key). */
    public void sendVerificationCode(String email, String phone, String otp) {
        dispatchEmail(email, otp);
        dispatchSms(phone, "ARGUS: " + String.format(DEFAULT_CODE_TEXT, otp));
    }

    /** Emails and SMSes a password-reset code (phone is the OTP key). */
    public void sendPasswordResetCode(String email, String phone, String otp) {
        dispatchEmail(email, otp);
        dispatchSms(phone, "ARGUS: Your password reset code is " + otp
                + ". Do not share this code with anyone. It expires in 5 minutes.");
    }

    private void dispatchEmail(String email, String otp) {
        executor.submit(() -> emailService.sendVerificationCode(email, otp));
    }

    private void dispatchSms(String phone, String message) {
        executor.submit(() -> smsService.sendSms(phone, message));
    }

    void shutdownGracefully() {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
}