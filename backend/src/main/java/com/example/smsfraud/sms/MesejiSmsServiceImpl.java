package com.example.smsfraud.sms;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

/**
 * Meseji (https://www.meseji.co.tz) SMS gateway. Sends via their REST API:
 * <pre>
 *   POST {base-url}/sms/send
 *   header: x-api-key: {api-key}
 *   body:   { "sender_id": "ARGUS", "message": "...", "contacts": "255744963858, ..." }
 * </pre>
 * Contacts are E.164 numbers without a leading "+" (Tanzanian numbers start with 255).
 */
@Service
@ConditionalOnProperty(name = "sms.provider", havingValue = "meseji", matchIfMissing = true)
public class MesejiSmsServiceImpl implements SmsSenderService {

    private static final Logger log = LoggerFactory.getLogger(MesejiSmsServiceImpl.class);

    private final RestTemplate restTemplate;
    private final String apiKey;
    private final String senderId;
    private final String baseUrl;

    public MesejiSmsServiceImpl(RestTemplate restTemplate,
                                @Value("${meseji.api-key:}") String apiKey,
                                @Value("${meseji.sender-id:MESEJI}") String senderId,
                                @Value("${meseji.base-url:https://meseji.co.tz/api/v1}") String baseUrl) {
        this.restTemplate = restTemplate;
        this.apiKey = apiKey;
        this.senderId = senderId;
        this.baseUrl = baseUrl;
    }

    @Override
    public void sendSms(String toPhoneNumber, String messageText) {
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("Cannot send SMS: Meseji API key is not configured (meseji.api-key).");
            return;
        }

        String contact = toE164(toPhoneNumber);
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("x-api-key", apiKey);

            Map<String, Object> body = Map.of(
                    "sender_id", senderId,
                    "message", messageText,
                    "contacts", contact
            );

            ResponseEntity<Map> response = restTemplate.postForEntity(
                    baseUrl + "/sms/send",
                    new HttpEntity<>(body, headers),
                    Map.class
            );

            Object batchId = response.getBody() != null ? response.getBody().get("batch_id") : null;
            Object status = response.getBody() != null ? response.getBody().get("status") : null;
            log.info("SMS queued to {} via Meseji (sender_id={}). batch_id={}, status={}",
                    contact, senderId, batchId, status);
        } catch (org.springframework.web.client.HttpStatusCodeException e) {
            // Surface Meseji's own error body (e.g. invalid key, unapproved sender ID).
            log.error("Meseji rejected SMS to {} (sender_id={}): HTTP {} — {}",
                    contact, senderId, e.getStatusCode(), e.getResponseBodyAsString());
        } catch (Exception e) {
            log.error("Failed to send SMS to {} via Meseji: {}", contact, e.getMessage());
        }
    }

    /**
     * Normalizes a stored phone number to the E.164 format Meseji expects:
     * no "+", Tanzanian numbers prefixed with 255.
     * <ul>
     *   <li>"+255744963858" -> "255744963858"</li>
     *   <li>"0744963858"     -> "255744963858"</li>
     *   <li>"744963858"      -> "255744963858"</li>
     *   <li>"255744963858"   -> unchanged</li>
     * </ul>
     */
    private String toE164(String phone) {
        if (phone == null) {
            return "";
        }
        String digits = phone.replaceAll("[^0-9]", "");
        if (digits.startsWith("00")) {
            digits = digits.substring(2);
        }
        if (digits.startsWith("0")) {
            digits = "255" + digits.substring(1);
        } else if (!digits.startsWith("255") && digits.length() == 9) {
            digits = "255" + digits;
        }
        return digits;
    }
}
