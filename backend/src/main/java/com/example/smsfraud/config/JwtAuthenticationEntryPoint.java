package com.example.smsfraud.config;

import com.example.smsfraud.dto.response.ErrorResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.time.LocalDateTime;

/**
 * JWT Authentication Entry Point - Handles 401 Unauthorized responses
 * Returns JSON error instead of redirecting to login page
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authException
    ) throws IOException {
        
        log.warn("Authentication failed: {} - {}", request.getRequestURI(), authException.getMessage());

        ErrorResponse errorResponse = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.UNAUTHORIZED.value())
            .error(HttpStatus.UNAUTHORIZED.getReasonPhrase())
            .message(getErrorMessage(authException))
            .path(request.getRequestURI())
            .build();

        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json");
        response.getWriter().write(objectMapper.writeValueAsString(errorResponse));
    }

    private String getErrorMessage(AuthenticationException authException) {
        String message = authException.getMessage();
        
        if (message == null) {
            return "Authentication failed. Please provide a valid JWT token.";
        }
        
        if (message.contains("expired")) {
            return "JWT token has expired. Please refresh your token.";
        }
        
        if (message.contains("signature") || message.contains("Invalid")) {
            return "Invalid JWT token. Please check your token.";
        }
        
        if (message.contains("malformed") || message.contains("well-formed")) {
            return "Malformed JWT token. Please provide a valid token.";
        }
        
        if (message.contains("Missing")) {
            return "No JWT token provided. Please include a valid token.";
        }
        
        return "Authentication failed: " + message;
    }
}