package com.example.smsfraud.config;

import com.example.smsfraud.entity.User;
import com.example.smsfraud.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

/**
 * 🔐 OTP SERVICE - Email Only
 * 
 * Purpose: Handles One-Time Password (OTP) generation, storage, and validation.
 * OTPs are sent via EMAIL only (not SMS).
 * 
 * All OTP operations are keyed by EMAIL address.
 * 
 * Called by: AuthService (registration, password reset)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OtpService {

    // ============================================================
    // DEPENDENCY INJECTION
    // ============================================================
    
    private final RedisTemplate<String, Object> redisTemplate;
    private final EmailService emailService;

    // ============================================================
    // CONSTANTS
    // ============================================================
    
    /**
     * Redis key prefix for OTP storage
     * Pattern: "otp:email:{email}"
     * Example: "otp:email:john.doe@example.com"
     */
    private static final String OTP_PREFIX = "otp:email:";
    
    /**
     * Redis key prefix for OTP attempt tracking
     * Pattern: "otp:attempts:email:{email}"
     * Example: "otp:attempts:email:john.doe@example.com"
     */
    private static final String OTP_ATTEMPTS_PREFIX = "otp:attempts:email:";
    
    /**
     * OTP validity duration - 5 minutes
     * Users must enter OTP within this time
     */
    private static final Duration OTP_TTL = Duration.ofMinutes(5);
    
    /**
     * Attempt counter validity - 15 minutes
     * After 15 minutes, attempts reset
     */
    private static final Duration ATTEMPTS_TTL = Duration.ofMinutes(15);
    
    /**
     * Maximum number of OTP attempts before blocking
     * Prevents brute force attacks on OTP
     */
    private static final int MAX_ATTEMPTS = 3;
    
    /**
     * OTP length - 6 digits
     */
    private static final int OTP_LENGTH = 6;
    
    /**
     * SecureRandom for generating cryptographically secure OTPs
     */
    private static final SecureRandom secureRandom = new SecureRandom();

    // ============================================================
    // OTP GENERATION
    // ============================================================
    
    /**
     * 🔑 generateOtp - Generate and send OTP via email
     * 
     * @param user - User who requested OTP
     * @return String - 6-digit OTP
     * @throws BusinessException if max attempts exceeded
     */
    public String generateOtp(User user) {
        String email = user.getEmail();
        log.info("Generating OTP for email: {}", email);
        
        // ===== STEP 1: Check if user can request OTP =====
        if (!canRequestOtp(email)) {
            int remainingAttempts = getRemainingAttempts(email);
            log.warn("OTP request blocked for {}. Remaining attempts: {}", 
                    email, remainingAttempts);
            throw new BusinessException(
                "Too many OTP attempts. Please wait " + 
                ATTEMPTS_TTL.toMinutes() + " minutes before trying again."
            );
        }
        
        // ===== STEP 2: Generate secure OTP =====
        String otp = generateSecureOtp();
        log.debug("OTP generated for {}: {}", email, otp);
        
        // ===== STEP 3: Store OTP in Redis =====
        // Key: "otp:email:{email}"
        // Value: "123456"
        // TTL: 5 minutes
        String key = OTP_PREFIX + email;
        redisTemplate.opsForValue().set(key, otp, OTP_TTL);
        
        // ===== STEP 4: Send OTP via email =====
        emailService.sendOtpEmail(user, otp);
        
        // ===== STEP 5: Increment attempt counter =====
        incrementOtpAttempts(email);
        
        // ===== STEP 6: Log success =====
        log.info("OTP stored and emailed to {} with TTL of {} minutes", 
                email, OTP_TTL.toMinutes());
        
        return otp;
    }

    /**
     * 🔑 generateOtp - Generate and send OTP via email (overload with custom email)
     * 
     * @param email - User's email address
     * @param user - User who requested OTP
     * @return String - 6-digit OTP
     */
    public String generateOtp(String email, User user) {
        log.info("Generating OTP for email: {}", email);
        return generateOtp(user); // Reuse the main method
    }

    // ============================================================
    // OTP VALIDATION
    // ============================================================
    
    /**
     * ✅ validateOtp - Validate OTP
     * 
     * @param email - User's email address
     * @param otp - OTP entered by user
     * @return true if valid, false otherwise
     */
    public boolean validateOtp(String email, String otp) {
        log.info("Validating OTP for email: {}", email);
        
        // ===== STEP 1: Check if too many invalid attempts =====
        if (!canAttemptOtp(email)) {
            log.warn("OTP validation blocked for {}. Too many invalid attempts.", email);
            return false;
        }
        
        // ===== STEP 2: Get stored OTP from Redis =====
        String key = OTP_PREFIX + email;
        String storedOtp = (String) redisTemplate.opsForValue().get(key);
        
        // ===== STEP 3: Check if OTP exists =====
        if (storedOtp == null) {
            log.warn("OTP expired or not found for email: {}", email);
            // Still increment attempts to prevent guessing
            incrementInvalidAttempts(email);
            return false;
        }
        
        // ===== STEP 4: Validate OTP =====
        boolean isValid = storedOtp.equals(otp);
        
        if (isValid) {
            // ===== VALID OTP =====
            log.info("OTP validated successfully for email: {}", email);
            
            // Delete OTP (one-time use)
            redisTemplate.delete(key);
            
            // Reset attempt counters
            resetOtpAttempts(email);
            
            return true;
            
        } else {
            // ===== INVALID OTP =====
            log.warn("Invalid OTP provided for email: {}", email);
            
            // Increment failed attempts
            incrementInvalidAttempts(email);
            
            // Check if max attempts reached
            if (!canAttemptOtp(email)) {
                // Delete OTP to prevent further guessing
                redisTemplate.delete(key);
                log.warn("Max attempts reached for email: {}. OTP deleted.", email);
            }
            
            return false;
        }
    }

    // ============================================================
    // ATTEMPT TRACKING - All keyed by EMAIL
    // ============================================================
    
    /**
     * 🔢 canRequestOtp - Check if user can request a new OTP
     * 
     * @param email - User's email address
     * @return true if can request, false if blocked
     */
    public boolean canRequestOtp(String email) {
        String key = OTP_ATTEMPTS_PREFIX + email;
        Integer attempts = (Integer) redisTemplate.opsForValue().get(key);
        return attempts == null || attempts < MAX_ATTEMPTS;
    }
    
    /**
     * 🔢 canAttemptOtp - Check if user can attempt OTP validation
     * 
     * @param email - User's email address
     * @return true if can attempt, false if blocked
     */
    public boolean canAttemptOtp(String email) {
        String key = OTP_ATTEMPTS_PREFIX + email;
        Integer attempts = (Integer) redisTemplate.opsForValue().get(key);
        return attempts == null || attempts < MAX_ATTEMPTS;
    }
    
    /**
     * 🔢 incrementOtpAttempts - Increment OTP request counter
     */
    private void incrementOtpAttempts(String email) {
        String key = OTP_ATTEMPTS_PREFIX + email;
        Integer attempts = (Integer) redisTemplate.opsForValue().get(key);
        
        if (attempts == null) {
            attempts = 0;
        }
        attempts++;
        
        redisTemplate.opsForValue().set(key, attempts, ATTEMPTS_TTL);
        
        log.debug("OTP attempts for email {}: {}/{}", 
                email, attempts, MAX_ATTEMPTS);
    }
    
    /**
     * 🔢 incrementInvalidAttempts - Increment invalid OTP counter
     */
    private void incrementInvalidAttempts(String email) {
        String key = OTP_ATTEMPTS_PREFIX + email;
        Integer attempts = (Integer) redisTemplate.opsForValue().get(key);
        
        if (attempts == null) {
            attempts = 0;
        }
        attempts++;
        
        redisTemplate.opsForValue().set(key, attempts, ATTEMPTS_TTL);
        
        log.debug("Invalid OTP attempts for email {}: {}/{}", 
                email, attempts, MAX_ATTEMPTS);
    }
    
    /**
     * 🔢 resetOtpAttempts - Reset attempt counter
     */
    private void resetOtpAttempts(String email) {
        String key = OTP_ATTEMPTS_PREFIX + email;
        redisTemplate.delete(key);
        log.debug("OTP attempts reset for email: {}", email);
    }
    
    /**
     * 🔢 getRemainingAttempts - Get remaining attempts
     */
    public int getRemainingAttempts(String email) {
        String key = OTP_ATTEMPTS_PREFIX + email;
        Integer attempts = (Integer) redisTemplate.opsForValue().get(key);
        
        if (attempts == null) {
            return MAX_ATTEMPTS;
        }
        return Math.max(0, MAX_ATTEMPTS - attempts);
    }

    // ============================================================
    // OTP GENERATION HELPERS
    // ============================================================
    
    /**
     * 🔢 generateSecureOtp - Generate cryptographically secure OTP
     * 
     * @return 6-digit OTP as String (e.g., "123456")
     */
    private String generateSecureOtp() {
        int otpNumber = 100000 + secureRandom.nextInt(900000);
        return String.valueOf(otpNumber);
    }

    // ============================================================
    // HELPER METHODS
    // ============================================================
    
    /**
     * 🔍 isOtpExpired - Check if OTP is expired
     */
    public boolean isOtpExpired(String email) {
        String key = OTP_PREFIX + email;
        return Boolean.FALSE.equals(redisTemplate.hasKey(key));
    }
    
    /**
     * 🔍 getOtpTTL - Get remaining TTL in seconds
     */
    public Long getOtpTTL(String email) {
        String key = OTP_PREFIX + email;
        return redisTemplate.getExpire(key, TimeUnit.SECONDS);
    }
    
    /**
     * 🔍 deleteOtp - Delete OTP (manual cleanup)
     */
    public void deleteOtp(String email) {
        String key = OTP_PREFIX + email;
        redisTemplate.delete(key);
        log.info("OTP manually deleted for email: {}", email);
    }
}