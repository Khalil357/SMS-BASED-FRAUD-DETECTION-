package com.example.smsfraud.user;

import com.example.smsfraud.common.dto.ApiResponse;
import com.example.smsfraud.common.exception.NotFoundException;
import com.example.smsfraud.user.dto.UserResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/**
 * Endpoints for the authenticated user to read their own profile. Available to any
 * authenticated principal ({@code ADMIN} or {@code USER}).
 */
@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserRepository userRepository;

    public UserController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @GetMapping("/me")
    @PreAuthorize("hasAnyRole('ADMIN','USER')")
    public ResponseEntity<ApiResponse<UserResponse>> me(Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        User user = userRepository.findByIdWithRole(userId)
                .orElseThrow(() -> new NotFoundException("User not found"));
        return ResponseEntity.ok(ApiResponse.ok("Current user", UserResponse.from(user)));
    }
}
