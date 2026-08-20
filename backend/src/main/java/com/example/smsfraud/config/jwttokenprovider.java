package com.example.smsfraud.config;

import com.example.smsfraud.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;

@Component // indicates that this class is a Spring component and will be managed by the Spring container
@Slf4j  // Lombok annotation to automatically generate a logger instance for this class

public class JwtTokenProvider {

    @Value("${jwt.secret}") // injects the value of the jwt.secret property from the application properties file into this field
    private String secretKey; // secret key used for signing the JWT tokens

    @Value("${jwt.expiration}") // injects the value of the jwt.expiration property from the application properties file into this field
    private Long jwtExpiration; // expiration time for the JWT tokens in milliseconds

    public String generateAccessToken(User user) {
        // Create data to embed in token
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", user.getId());
        claims.put("role", user.getRole().name());
        claims.put("email", user.getEmail());
        claims.put("mobileNumber", user.getPhoneNumber());
        claims.put("tokenVersion", user.getRefreshTokenVersion());
        claims.put("loginMethod", "email");
        
        // Generate the token with the claims and return it
    return buildToken(claims, user.getEmail(), jwtExpiration);
    }

    // method to build the JWT token with the provided claims, subject, and expiration time
    public String generateRefreshToken(User user) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", user.getId());
        claims.put("tokenVersion", user.getRefreshTokenVersion());
        claims.put("type", "REFRESH");  // Identifies as refresh token
        
        return buildToken(claims, user.getEmail(), refreshExpiration);
    }

    public String generateTokenForGoogleUser(User user, String googleId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", user.getId());
        claims.put("role", user.getRole().name());
        claims.put("email", user.getEmail());
        claims.put("googleId", googleId);
        claims.put("loginMethod", "google");
        claims.put("tokenVersion", user.getRefreshTokenVersion());
        
        return buildToken(claims, user.getEmail(), jwtExpiration);
    }

    // Creates the actual JWT token with all claims and signatures.
private String buildToken(Map<String, Object> claims, 
        String subject, 
        Long expiration) {
        
        Date now = new Date(System.currentTimeMillis());
        Date expiryDate = new Date(now.getTime() + expiration);
        
        return Jwts.builder()
            .setClaims(claims)                 // User data
            .setSubject(subject)               // Email as subject
            .setIssuer("sms-fraud-service")    // Who issued the token
            .setAudience("sms-fraud-apps")     // Who can use it
            .setIssuedAt(now)                  // When it was issued
            .setExpiration(expiryDate)         // When it expires
            .signWith(getSignInKey(), SignatureAlgorithm.HS256)  // Sign it
            .compact();  // Build the token
    }
    
// Validation of token
    public boolean validateToken(String token) {
        try {
            // Attempt to parse the token
            // If it throws an exception, the token is invalid
            Jwts.parserBuilder()
                .setSigningKey(getSignInKey())
                .build()
                .parseClaimsJws(token);

            // If we get here, the token is valid
            return true;
    } 
    catch (Exception e) {
    log.error("Token validation failed: {}", e.getMessage());
            return false;
        }
    }

    private boolean isTokenExpired(Claims claims) {
        Date expiration = claims.getExpiration();
        Date now = new Date();
        return expiration.before(now);
    }
// Extract claims from token
    public String extractUserId(String token) {
        return extractClaim(token, claims -> claims.get("userId", String.class));
    }

    public String extractEmail(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public String extractRole(String token) {
        return extractClaim(token, claims -> claims.get("role", String.class));
    }
    public Long extractTokenVersion(String token) {
        return extractClaim(token, claims -> claims.get("tokenVersion", Long.class));
    }

    public boolean isRefreshToken(String token) { // Check if the token is a refresh token
        String type = extractClaim(token, claims -> claims.get("type", String.class));
        return "REFRESH".equals(type);
    }

    // Generic method to extract any claim from the token
    public String extractLoginMethod(String token) {
        return extractClaim(token, claims -> claims.get("loginMethod", String.class));
    }

    private <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);  // Extract all claims from the token
        return claimsResolver.apply(claims);
    }

    
    private Claims extractAllClaims(String token) { // this is a private method that extracts all claims from the JWT token using the secret key for validation
        return Jwts.parserBuilder()
            .setSigningKey(getSignInKey())
            .build()
            .parseClaimsJws(token)
            .getBody();
    }

    // This method returns the signing key used for signing and validating the JWT tokens. It converts the secret key string into a byte array and then creates a Key object using the HMAC SHA algorithm.
    private Key getSignInKey() {
        byte[] keyBytes = secretKey.getBytes();
        return Keys.hmacShaKeyFor(keyBytes);
    }
}
