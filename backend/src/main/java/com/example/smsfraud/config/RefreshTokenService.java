package com.example.smsfraud.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Set;
import java.util.UUID;

/**
 * Refresh Token Service - Manages refresh tokens in Redis
 * Pattern: refresh:{userId}:{deviceId} | TTL: 7 days
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RefreshTokenService {

    private final RedisTemplate<String, Object> redisTemplate;

    private static final String REFRESH_PREFIX = "refresh:";
    private static final Duration REFRESH_TTL = Duration.ofDays(7);

    /**
     * Store refresh token for a user/device
     */
    public void storeRefreshToken(String userId, String deviceId, String refreshToken) {
        String key = REFRESH_PREFIX + userId + ":" + deviceId;
        redisTemplate.opsForValue().set(key, refreshToken, REFRESH_TTL);
        log.info("Refresh token stored for user: {}, device: {}", userId, deviceId);
    }

    /**
     * Validate refresh token
     */
    public boolean validateRefreshToken(String userId, String deviceId, String refreshToken) {
        String key = REFRESH_PREFIX + userId + ":" + deviceId;
        String storedToken = (String) redisTemplate.opsForValue().get(key);
        
        if (storedToken == null) {
            log.warn("Refresh token not found for user: {}, device: {}", userId, deviceId);
            return false;
        }
        
        boolean isValid = storedToken.equals(refreshToken);
        if (!isValid) {
            log.warn("Invalid refresh token for user: {}, device: {}", userId, deviceId);
        }
        return isValid;
    }

    /**
     * Revoke refresh token for a specific device
     */
    public void deleteRefreshToken(String userId, String deviceId) {
        String key = REFRESH_PREFIX + userId + ":" + deviceId;
        Boolean deleted = redisTemplate.delete(key);
        if (Boolean.TRUE.equals(deleted)) {
            log.info("Refresh token revoked for user: {}, device: {}", userId, deviceId);
        }
    }

    /**
     * Revoke ALL refresh tokens for a user (global logout / password reset)
     */
    public void deleteAllRefreshTokens(String userId) {
        String pattern = REFRESH_PREFIX + userId + ":*";
        Set<String> keys = redisTemplate.keys(pattern);
        
        if (keys != null && !keys.isEmpty()) {
            Long deletedCount = redisTemplate.delete(keys);
            log.info("All refresh tokens revoked for user: {}. {} tokens deleted.", 
                    userId, deletedCount);
        }
    }

    /**
     * Get refresh token for a user/device
     */
    public String getRefreshToken(String userId, String deviceId) {
        String key = REFRESH_PREFIX + userId + ":" + deviceId;
        return (String) redisTemplate.opsForValue().get(key);
    }

    /**
     * Get remaining TTL in seconds
     */
    public Long getRefreshTokenTTL(String userId, String deviceId) {
        String key = REFRESH_PREFIX + userId + ":" + deviceId;
        return redisTemplate.getExpire(key);
    }

    /**
     * Get number of active devices for a user
     */
    public int getDeviceCount(String userId) {
        String pattern = REFRESH_PREFIX + userId + ":*";
        Set<String> keys = redisTemplate.keys(pattern);
        return keys != null ? keys.size() : 0;
    }

    /**
     * Get all device IDs for a user
     */
    public Set<String> getAllDeviceIds(String userId) {
        String pattern = REFRESH_PREFIX + userId + ":*";
        Set<String> keys = redisTemplate.keys(pattern);
        Set<String> deviceIds = new java.util.HashSet<>();
        
        if (keys != null) {
            for (String key : keys) {
                String[] parts = key.split(":");
                if (parts.length == 3) {
                    deviceIds.add(parts[2]);
                }
            }
        }
        return deviceIds;
    }

    /**
     * Generate unique refresh token ID
     */
    public String generateRefreshTokenId() {
        return UUID.randomUUID().toString().replace("-", "");
    }
}