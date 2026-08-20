package com.example.smsfraud.exception;

import com.example.smsfraud.dto.response.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    // ============================================================
    // REGISTRATION EXCEPTIONS (7)
    // ============================================================
    
    @ExceptionHandler(RegistrationException.class)
    public ResponseEntity<ErrorResponse> handleRegistrationException(
            RegistrationException ex, HttpServletRequest request) {
        log.error("Registration error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        return buildErrorResponse(ex, request, HttpStatus.CONFLICT);
    }

    // ============================================================
    // LOGIN EXCEPTIONS (6)
    // ============================================================
    
    @ExceptionHandler(LoginException.class)
    public ResponseEntity<ErrorResponse> handleLoginException(
            LoginException ex, HttpServletRequest request) {
        log.error("Login error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        return buildErrorResponse(ex, request, HttpStatus.UNAUTHORIZED);
    }

    // ============================================================
    // OTP EXCEPTIONS (5)
    // ============================================================
    
    @ExceptionHandler(OtpException.class)
    public ResponseEntity<ErrorResponse> handleOtpException(
            OtpException ex, HttpServletRequest request) {
        log.error("OTP error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        
        ErrorResponse.ErrorResponseBuilder builder = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.BAD_REQUEST.value())
            .error(HttpStatus.BAD_REQUEST.getReasonPhrase())
            .message(ex.getMessage())
            .path(request.getRequestURI())
            .errorCode(ex.getErrorCode());
        
        if (ex.hasDetails()) {
            builder.details(ex.getDetails());
        }
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(builder.build());
    }

    // ============================================================
    // TOKEN EXCEPTIONS (6)
    // ============================================================
    
    @ExceptionHandler(TokenException.class)
    public ResponseEntity<ErrorResponse> handleTokenException(
            TokenException ex, HttpServletRequest request) {
        log.error("Token error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        return buildErrorResponse(ex, request, HttpStatus.UNAUTHORIZED);
    }

    // ============================================================
    // REFRESH TOKEN EXCEPTIONS (4)
    // ============================================================
    
    @ExceptionHandler(RefreshTokenException.class)
    public ResponseEntity<ErrorResponse> handleRefreshTokenException(
            RefreshTokenException ex, HttpServletRequest request) {
        log.error("Refresh token error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        return buildErrorResponse(ex, request, HttpStatus.UNAUTHORIZED);
    }

    // ============================================================
    // LOCKED ACCOUNT EXCEPTIONS (4)
    // ============================================================
    
    @ExceptionHandler(LockedAccountException.class)
    public ResponseEntity<ErrorResponse> handleLockedAccountException(
            LockedAccountException ex, HttpServletRequest request) {
        log.error("Account locked error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        return buildErrorResponse(ex, request, HttpStatus.LOCKED);
    }

    // ============================================================
    // USER NOT FOUND EXCEPTIONS (3)
    // ============================================================
    
    @ExceptionHandler(UserNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleUserNotFoundException(
            UserNotFoundException ex, HttpServletRequest request) {
        log.error("User not found error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        return buildErrorResponse(ex, request, HttpStatus.NOT_FOUND);
    }

    // ============================================================
    // PASSWORD POLICY EXCEPTIONS (7)
    // ============================================================
    
    @ExceptionHandler(PasswordPolicyException.class)
    public ResponseEntity<ErrorResponse> handlePasswordPolicyException(
            PasswordPolicyException ex, HttpServletRequest request) {
        log.error("Password policy error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        return buildErrorResponse(ex, request, HttpStatus.BAD_REQUEST);
    }

    // ============================================================
    // BASE AUTH EXCEPTION
    // ============================================================
    
    @ExceptionHandler(AuthException.class)
    public ResponseEntity<ErrorResponse> handleAuthException(
            AuthException ex, HttpServletRequest request) {
        log.error("Auth error: {} - Code: {}", ex.getMessage(), ex.getErrorCode());
        return buildErrorResponse(ex, request, HttpStatus.valueOf(ex.getStatus()));
    }

    // ============================================================
    // SPRING SECURITY EXCEPTIONS
    // ============================================================
    
    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ErrorResponse> handleAuthenticationException(
            AuthenticationException ex, HttpServletRequest request) {
        log.warn("Spring Security authentication error: {}", ex.getMessage());
        
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.UNAUTHORIZED.value())
            .error(HttpStatus.UNAUTHORIZED.getReasonPhrase())
            .message("Authentication failed: " + getSafeMessage(ex.getMessage()))
            .path(request.getRequestURI())
            .errorCode("AUTH_SPRING_001")
            .build();
        
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(error);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDeniedException(
            AccessDeniedException ex, HttpServletRequest request) {
        log.warn("Access denied: {}", ex.getMessage());
        
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.FORBIDDEN.value())
            .error(HttpStatus.FORBIDDEN.getReasonPhrase())
            .message("Access denied: You don't have permission to access this resource.")
            .path(request.getRequestURI())
            .errorCode("AUTH_ACCESS_DENIED_001")
            .build();
        
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error);
    }

    // ============================================================
    // VALIDATION EXCEPTIONS
    // ============================================================
    
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(
            MethodArgumentNotValidException ex, HttpServletRequest request) {
        log.warn("Validation error: {}", ex.getMessage());
        
        Map<String, String> validationErrors = new HashMap<>();
        ex.getBindingResult().getAllErrors().forEach((error) -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            validationErrors.put(fieldName, errorMessage);
        });
        
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.BAD_REQUEST.value())
            .error(HttpStatus.BAD_REQUEST.getReasonPhrase())
            .message("Validation failed. Please check the request parameters.")
            .path(request.getRequestURI())
            .validationErrors(validationErrors)
            .errorCode("AUTH_VALIDATION_001")
            .build();
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    // ============================================================
    // GENERIC EXCEPTIONS
    // ============================================================
    
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorResponse> handleIllegalArgumentException(
            IllegalArgumentException ex, HttpServletRequest request) {
        log.warn("Illegal argument: {}", ex.getMessage());
        
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.BAD_REQUEST.value())
            .error(HttpStatus.BAD_REQUEST.getReasonPhrase())
            .message("Invalid request parameter: " + getSafeMessage(ex.getMessage()))
            .path(request.getRequestURI())
            .errorCode("AUTH_ARGUMENT_001")
            .build();
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ErrorResponse> handleRuntimeException(
            RuntimeException ex, HttpServletRequest request) {
        log.error("Runtime error: {}", ex.getMessage(), ex);
        
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
            .error(HttpStatus.INTERNAL_SERVER_ERROR.getReasonPhrase())
            .message("An unexpected error occurred. Please try again later.")
            .path(request.getRequestURI())
            .errorCode("AUTH_SYSTEM_001")
            .build();
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(
            Exception ex, HttpServletRequest request) {
        log.error("Unexpected error: {}", ex.getMessage(), ex);
        
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
            .error(HttpStatus.INTERNAL_SERVER_ERROR.getReasonPhrase())
            .message("An unexpected error occurred. Please try again later.")
            .path(request.getRequestURI())
            .errorCode("AUTH_SYSTEM_002")
            .build();
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }

    // ============================================================
    // HELPER METHODS
    // ============================================================
    
    private ResponseEntity<ErrorResponse> buildErrorResponse(
            AuthException ex, HttpServletRequest request, HttpStatus status) {
        
        ErrorResponse.ErrorResponseBuilder builder = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(status.value())
            .error(status.getReasonPhrase())
            .message(ex.getMessage())
            .path(request.getRequestURI())
            .errorCode(ex.getErrorCode());
        
        if (ex.hasDetails()) {
            builder.details(ex.getDetails());
        }
        
        return ResponseEntity.status(status).body(builder.build());
    }

    private String getSafeMessage(String message) {
        if (message == null) {
            return "Authentication failed. Please try again.";
        }
        if (message.contains("SQL") || message.contains("JDBC") || message.contains("Hibernate")) {
            return "A database error occurred. Please try again.";
        }
        if (message.contains("Stack trace:")) {
            return "An error occurred. Please try again.";
        }
        return message;
    }
}