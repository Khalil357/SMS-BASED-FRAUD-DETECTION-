package com.example.smsfraud.sms;

import com.example.smsfraud.common.exception.UnauthorizedException;
import com.example.smsfraud.sms.dto.CreateSmsRequest;
import com.example.smsfraud.sms.dto.SmsResponse;
import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class SmsServiceImpl implements SmsService {

    private final SmsRepository smsRepository;
    private final UserRepository userRepository;
    private final ApplicationEventPublisher eventPublisher;

    public SmsServiceImpl(SmsRepository smsRepository, UserRepository userRepository, ApplicationEventPublisher eventPublisher) {
        this.smsRepository = smsRepository;
        this.userRepository = userRepository;
        this.eventPublisher = eventPublisher;
    }

    @Override
    @Transactional
    public SmsResponse ingest(UUID authenticatedUserId, CreateSmsRequest request) {
        //Validate incoming request
        User user = userRepository.findById(authenticatedUserId)
                .orElseThrow(() -> new UnauthorizedException("Authenticated user no longer exists"));

        Sms sms = new Sms();
        sms.setUser(user);
        sms.setSenderPhoneNumber(request.senderPhoneNumber());
        sms.setMessageBody(request.messageBody());
        sms.setReceivedAt(request.receivedAt());
        sms.setDeviceSmsId(request.deviceSmsId());

        return SmsResponse.from(smsRepository.save(sms));
    }
}
