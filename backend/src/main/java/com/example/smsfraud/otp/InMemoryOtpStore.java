package com.example.smsfraud.otp;

import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/** In-memory {@link OtpStore} for development; replace with Redis for production. */
@Component
public class InMemoryOtpStore implements OtpStore {

    private final Map<String, OtpCode> store = new ConcurrentHashMap<>();

    @Override
    public void save(String phone, OtpCode code) {
        store.put(phone, code);
    }

    @Override
    public Optional<OtpCode> find(String phone) {
        return Optional.ofNullable(store.get(phone));
    }

    @Override
    public void delete(String phone) {
        store.remove(phone);
    }
}
