package com.example.smsfraud.otp;

import org.springframework.context.annotation.Profile;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

/** Redis-backed OTP storage used by deployed instances. */
@Component
@Profile("prod")
public class RedisOtpStore implements OtpStore {

    private static final String KEY_PREFIX = "smsfraud:otp:";

    private final StringRedisTemplate redis;

    public RedisOtpStore(StringRedisTemplate redis) {
        this.redis = redis;
    }

    @Override
    public void save(String phone, OtpCode code) {
        Duration ttl = Duration.between(Instant.now(), code.expiresAt());
        if (ttl.isNegative() || ttl.isZero()) {
            delete(phone);
            return;
        }
        redis.opsForValue().set(key(phone), code.code(), ttl);
    }

    @Override
    public Optional<OtpCode> find(String phone) {
        String key = key(phone);
        String code = redis.opsForValue().get(key);
        if (code == null) {
            return Optional.empty();
        }
        Long ttlSeconds = redis.getExpire(key);
        if (ttlSeconds == null || ttlSeconds <= 0) {
            return Optional.empty();
        }
        return Optional.of(new OtpCode(code, Instant.now().plusSeconds(ttlSeconds)));
    }

    @Override
    public void delete(String phone) {
        redis.delete(key(phone));
    }

    private String key(String phone) {
        return KEY_PREFIX + phone;
    }
}
