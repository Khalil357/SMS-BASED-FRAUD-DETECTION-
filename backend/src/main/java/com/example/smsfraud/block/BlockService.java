package com.example.smsfraud.block;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class BlockService {

    private final UserBlockedNumberRepository blockedNumberRepository;

    public BlockService(UserBlockedNumberRepository blockedNumberRepository) {
        this.blockedNumberRepository = blockedNumberRepository;
    }

    @Transactional
    public void blockNumber(UUID userId, String phoneNumber, String reason) {
        if (blockedNumberRepository.existsByUserIdAndPhoneNumber(userId, phoneNumber)) {
            return;
        }
        UserBlockedNumber blocked = new UserBlockedNumber();
        blocked.setUserId(userId);
        blocked.setPhoneNumber(phoneNumber);
        blocked.setReason(reason);
        blockedNumberRepository.save(blocked);
    }

    @Transactional
    public void unblockNumber(UUID userId, String phoneNumber) {
        blockedNumberRepository.deleteByUserIdAndPhoneNumber(userId, phoneNumber);
    }

    public List<String> getBlockedNumbers(UUID userId) {
        return blockedNumberRepository.findByUserId(userId).stream()
                .map(UserBlockedNumber::getPhoneNumber)
                .collect(Collectors.toList());
    }

    public boolean isBlocked(UUID userId, String phoneNumber) {
        return blockedNumberRepository.existsByUserIdAndPhoneNumber(userId, phoneNumber);
    }
}
