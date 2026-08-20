package com.example.smsfraud.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
@Slf4j

public class JwtAuthenticationFilter extends OncePerRequestFilter {

    // This method is called for every incoming HTTP request. It checks for the presence of a JWT token in the Authorization header, validates it, and sets the authentication in the security context if valid.
    private final JwtTokenProvider jwtTokenProvider;
   // CustomUserDetailsService - Loads user from database
    private final CustomUserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {


        // STEP 1: Skip OPTIONS requests (CORS preflight)
    if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
        log.debug("Skipping authentication for OPTIONS request");
            filterChain.doFilter(request, response);
            return;
        }  

            // STEP 2: Extract the JWT token from the Authorization header
    final String authHeader = request.getHeader("Authorization");

            // STEP 3: If the Authorization header is missing or doesn't start with "Bearer ", log a debug message and continue the filter chain without setting authentication
    if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            log.debug("No valid Authorization header found - continuing unauthenticated");
            filterChain.doFilter(request, response);
            return; 
    }
        try {
            // ===== STEP 4: Extract JWT token =====
            // Remove "Bearer " prefix (7 characters)
            final String jwt = authHeader.substring(7);
            log.debug("Extracted JWT token: {}", jwt.substring(0, Math.min(20, jwt.length())) + "...");
    
            
            // ===== STEP 5: Extract email from token =====
            final String userEmail = jwtTokenProvider.extractEmail(jwt);
            
            // ===== STEP 6: Check if user exists and not already authenticated =====
            if (userEmail != null && 
            SecurityContextHolder.getContext().getAuthentication() == null) {
                
                log.debug("User email extracted: {}, attempting authentication", userEmail);

            // ===== STEP 7: Load user from database =====
            // This is where CustomUserDetailsService is called
                UserDetails userDetails = userDetailsService.loadUserByUsername(userEmail);

            // ===== STEP 8: Validate JWT token =====
    if (jwtTokenProvider.validateToken(jwt)) {
                    log.debug("JWT token validated successfully for: {}", userEmail);

            // ===== STEP 9: Create authentication token =====
            // This is what Spring Security uses for authorization
                    UsernamePasswordAuthenticationToken authToken = 
                        new UsernamePasswordAuthenticationToken(
                            userDetails,          // The user details
                            null,                 // No credentials (already validated)
                            userDetails.getAuthorities()  // User roles
                        );

            // ===== STEP 10: Add request details =====
            // Adds IP address, session ID, etc. to authentication
                    authToken.setDetails(
                        new WebAuthenticationDetailsSource().buildDetails(request)
                    );

                    // ===== STEP 11: Set authentication in SecurityContext =====
                    // This is what Spring Security checks for @PreAuthorize
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                    
                    log.info("User authenticated successfully: {}", userEmail);
                } else {
                    log.warn("JWT token validation failed for: {}", userEmail);
                }
            } else {
    if (userEmail == null) {
                    log.warn("Could not extract email from JWT token");
                } 
        else {
            log.debug("User already authenticated: {}", userEmail);
            }
            }
        } 
        catch (Exception e) {
            // ===== STEP 12: Handle any errors =====
            log.error("JWT authentication failed: {}", e.getMessage());
            // Clear context on error - prevents partial authentication
            SecurityContextHolder.clearContext();
        }
          // ===== STEP 13: Continue filter chain =====
        // Even if authentication failed, we continue so other filters can handle it
        filterChain.doFilter(request, response);
                    
}

  // FILTER SKIPPING LOGIC

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        
        // List of paths that don't need authentication
        boolean shouldSkip = 
            path.startsWith("/api/v1/auth/") ||      // Login, Register, etc.
            path.startsWith("/oauth2/") ||           // Google OAuth
            path.startsWith("/login/oauth2/") ||     // OAuth2 login
            path.startsWith("/swagger-ui/") ||       // Swagger UI
            path.startsWith("/v3/api-docs/") ||      // OpenAPI docs
            path.startsWith("/actuator/health") ||   // Health check
            path.startsWith("/actuator/info") ||     // Info endpoint
            path.equals("/") ||                      // Root
            path.equals("/error");                  // Error endpoint
        
    if (shouldSkip) {
        log.debug("Skipping JWT filter for public path: {}", path);
        }
        
        return shouldSkip;
    }
}
