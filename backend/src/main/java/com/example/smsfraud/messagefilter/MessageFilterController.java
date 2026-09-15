package com.example.smsfraud.messagefilter;

import com.example.smsfraud.messagefilter.dto.AppleMessageFilterRequest;
import com.example.smsfraud.messagefilter.dto.MessageFilterResponse;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Apple Message Filter network-deferral endpoint.
 *
 * <p>Security model: this endpoint is intentionally unauthenticated because iOS performs
 * the HTTPS POST on behalf of the extension and cannot attach the Flutter app's JWT.
 * Associated Domains ({@code messagefilter:}) + HTTPS constrain the caller in production.
 * The endpoint only returns a classification; it does not read or write per-user scan history.
 * Do not put secrets in the iOS extension.
 */
@RestController
@RequestMapping("/api/message-filter")
public class MessageFilterController {

    private final MessageFilterService messageFilterService;

    public MessageFilterController(MessageFilterService messageFilterService) {
        this.messageFilterService = messageFilterService;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public MessageFilterResponse classify(@RequestBody AppleMessageFilterRequest request) {
        return messageFilterService.classify(request);
    }
}
