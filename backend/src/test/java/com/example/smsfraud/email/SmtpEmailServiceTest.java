package com.example.smsfraud.email;

import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.Test;
import org.springframework.mail.javamail.JavaMailSender;

import java.util.Properties;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class SmtpEmailServiceTest {
    @Test
    void welcomeEmailContainsExactInitialCredentialsAndPortalLink() throws Exception {
        JavaMailSender sender = mock(JavaMailSender.class);
        MimeMessage message = new MimeMessage(Session.getInstance(new Properties()));
        when(sender.createMimeMessage()).thenReturn(message);
        SmtpEmailService service = new SmtpEmailService(sender, "noreply@example.com",
                "Argus", " https://d2wma51qvc2c0y.cloudfront.net/ ");

        service.sendWelcomeEmail("new-admin@example.com", "New Admin", "ADMIN", "Test<&Secret!42");

        verify(sender).send(message);
        assertEquals("new-admin@example.com", message.getAllRecipients()[0].toString());
        assertEquals("Welcome to Argus", message.getSubject());
        String body = (String) message.getContent();
        assertTrue(body.contains("Email: new-admin@example.com"));
        assertTrue(body.contains("Initial password: Test<&Secret!42"));
        assertTrue(body.contains("here:\nhttps://d2wma51qvc2c0y.cloudfront.net/\n"));
        assertTrue(body.contains("one-time code"));
        assertTrue(message.isMimeType("text/plain"));
    }

    @Test
    void deliveryFailureRemainsBestEffort() {
        JavaMailSender sender = mock(JavaMailSender.class);
        when(sender.createMimeMessage()).thenThrow(new IllegalStateException("Mail unavailable"));
        SmtpEmailService service = new SmtpEmailService(sender, "noreply@example.com",
                "Argus", "https://d2wma51qvc2c0y.cloudfront.net/");

        assertDoesNotThrow(() -> service.sendWelcomeEmail(
                "new-admin@example.com", "New Admin", "ADMIN", "TestSecret!42"));
    }
}
