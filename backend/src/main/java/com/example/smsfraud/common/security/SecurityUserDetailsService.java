package com.example.smsfraud.common.security;

import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Loads a {@link UserDetails} (with its DB role mapped to a {@code ROLE_*} authority)
 * by user id. Used by {@link JwtAuthenticationFilter} so that role-based access
 * control reflects the database on every request, not a cached claim.
 */
@Service
public class SecurityUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;

    public SecurityUserDetailsService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String userId) throws UsernameNotFoundException {
        User user = userRepository.findByIdWithRole(UUID.fromString(userId))
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + userId));
        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getUserId().toString())
                .password(user.getPasswordHash() == null ? "" : user.getPasswordHash())
                .authorities("ROLE_" + user.getRole().getRoleName())
                .disabled(!user.isActive())
                .accountLocked(user.isLocked())
                .build();
    }
}
