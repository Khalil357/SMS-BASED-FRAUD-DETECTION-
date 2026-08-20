package com.example.smsfraud.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Pattern;

@Component
@Slf4j
public class PasswordPolicy {

    private static final int MIN_LENGTH = 8;
    private static final int MAX_LENGTH = 50;

    private static final String PASSWORD_PATTERN = 
    "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$";

 // Set of common passwords to check against
    private static final Pattern PATTERN = Pattern.compile(PASSWORD_PATTERN);

// common passwords to reject
    private static final Set<String> COMMON_PASSWORDS = new HashSet<>(Arrays.asList(
        "password", "password123", "12345678", "qwerty", "admin", 
        "welcome", "letmein", "123456789", "password1", "abc123",
        "123456", "admin123", "qwerty123", "welcome1", "letmein123"
    ));

// method to validate the password against the defined policy
    public boolean isValid(String password) {
    if (password == null || password.isEmpty()) {
            log.warn("Password validation failed: Password is null or empty");
            return false;
        }

    if (password.length() < MIN_LENGTH) {
            log.warn("Password validation failed: Too short ({} characters, min {})", 
            password.length(), MIN_LENGTH);
            return false;
        }
        
    if (password.length() > MAX_LENGTH) {
            log.warn("Password validation failed: Too long ({} characters, max {})", 
            password.length(), MAX_LENGTH);
            return false;
        }

    if (!PATTERN.matcher(password).matches()) {
            log.warn("Password validation failed: Does not meet complexity requirements");
            return false;

        }
    if (COMMON_PASSWORDS.contains(password.toLowerCase())) {
            log.warn("Password validation failed: Password is too common");
            return false;
        }

    log.debug("Password validation successful");
        return true;
    }

// method to get the password requirements as a string for user feedback
    public String getRequirements() {
        return "Password must be between " + MIN_LENGTH + " and " + MAX_LENGTH + 
        " characters and contain:\n" +
        "• At least one uppercase letter (A-Z)\n" +
        "• At least one lowercase letter (a-z)\n" +
        "• At least one digit (0-9)\n" +
        "• At least one special character (@$!%*?&)\n" +
        "• Not be a commonly used password";
    }

    public boolean hasUpperCase(String password) {
        return password != null && password.matches(".*[A-Z].*");
    }
    
    public boolean hasLowerCase(String password) {
        return password != null && password.matches(".*[a-z].*");
    }
    
    public boolean hasDigit(String password) {
        return password != null && password.matches(".*\\d.*");
    }
    
    public boolean hasSpecialChar(String password) {
        return password != null && password.matches(".*[@$!%*?&].*");
    }

    // method to validate the password and return detailed validation results
    public ValidationResult validateWithDetails(String password) {
        ValidationResult result = new ValidationResult();
        
        if (password == null || password.isEmpty()) {
            result.addError("Password cannot be empty");
            return result;
        }
        
        if (password.length() < MIN_LENGTH) {
            result.addError("Password must be at least " + MIN_LENGTH + " characters");
        }
        if (password.length() > MAX_LENGTH) {
            result.addError("Password must be less than " + MAX_LENGTH + " characters");
        }
        
        if (!hasUpperCase(password)) {
            result.addError("Password must contain at least one uppercase letter");
        }
        
        if (!hasLowerCase(password)) {
            result.addError("Password must contain at least one lowercase letter");
        }
        
        if (!hasDigit(password)) {
            result.addError("Password must contain at least one digit");
        }
        
        if (!hasSpecialChar(password)) {
            result.addError("Password must contain at least one special character (@$!%*?&)");
        }
        
        if (COMMON_PASSWORDS.contains(password.toLowerCase())) {
            result.addError("Password is too common. Please choose a more unique password");
        }

        
        result.setValid(result.getErrors().isEmpty());
        return result;
    }

    // used for frontend to display password requirements to users
    public static class ValidationResult {
        private boolean valid;
        private final Set<String> errors = new HashSet<>();
        
        public boolean isValid() {
            return valid;
        }
        
        public void setValid(boolean valid) {
            this.valid = valid;
        }
        
        public Set<String> getErrors() {
            return errors;
        }
        public void addError(String error) {
            this.errors.add(error);
        }
    }
}



