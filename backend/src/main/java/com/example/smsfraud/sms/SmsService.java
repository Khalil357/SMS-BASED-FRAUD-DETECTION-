package com.example.smsfraud.sms;

public interface SmsService {
    /**
     * Sends an SMS message to a specific phone number.
     * @param toPhoneNumber the recipient's phone number (E.164 format)
     * @param message the SMS content
     */
    void sendSms(String toPhoneNumber, String message);
}
