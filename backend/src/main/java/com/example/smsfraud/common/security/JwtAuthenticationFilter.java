package com.example.smsfraud.common.security;

import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import io.jsonwebtoken.ExpiredJwtException;
import java.io.IOException;
import java.util.List;

/**
 * Reads a {@code Authorization: Bearer <token>} header, validates the JWT, and loads
 * the user's role from the database to populate the security context (so RBAC works).
 * A token is rejected unless it is an {@code access} token AND its {@code tokenVersion}
 * still matches the user's current version — the latter is what makes "bump the version"
 * revoke outstanding tokens instantly. A missing, invalid, expired, or revoked token —
 * or a disabled/locked user — leaves the context empty, which the authentication entry
 * point translates into a 401.
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";
    private static final String TYPE_ACCESS = "access";

    private final TokenProvider tokenProvider;
    private final UserRepository userRepository;

    public JwtAuthenticationFilter(TokenProvider tokenProvider, UserRepository userRepository) {
        this.tokenProvider = tokenProvider;
        this.userRepository = userRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String token = resolveToken(request);
        if (token != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            try {
                TokenClaims claims = tokenProvider.validateToken(token);
                if (TYPE_ACCESS.equals(claims.type())) {
                    User user = userRepository.findByIdWithRole(claims.userId()).orElse(null);
                    if (user != null
                            && user.isActive()
                            && !user.isLocked()
                            && claims.tokenVersion() != null
                            && claims.tokenVersion() == user.getTokenVersion()) {
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(
                                        user.getUserId().toString(),
                                        null,
                                        List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().getRoleName())));
                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    }
                }
            } catch (ExpiredJwtException e) {
                SecurityContextHolder.clearContext();
                request.setAttribute("authError", "Session expired");
            } catch (RuntimeException e) {
                SecurityContextHolder.clearContext();
            }
        }

        filterChain.doFilter(request, response);
    }

    private String resolveToken(HttpServletRequest request) {
        String bearer = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (bearer != null && bearer.startsWith(BEARER_PREFIX)) {
            return bearer.substring(BEARER_PREFIX.length());
        }
        return null;
    }
}
