package com.example.smsfraud.config; // package declaration
import com.example.smsfraud.entity.User; // import User entity which represents the user table in the database
import com.example.smsfaud.repository.UserRepository; // import UserRepository interface which extends JpaRepository for database operations
import lombok.RequiredArgsConstructor; // generates constructor with required arguments which are final fields or fields annotated with @NonNull
import lombok.extern.slf4j.Slf4j; //creates logger instance for logging data in the class
import org.springframework.security.core.userdetails.UserDetails; // import UserDetails interface which provides core user information
import org.springframework.security.core.userdetails.UserDetailsService; // import UserDetailsService interface which is used to retrieve user-related data
import org.springframework.security.core.userdetails.UsernameNotFoundException; // import UsernameNotFoundException which is thrown when a user is not found
import org.springframework.stereotype.Service; // import Service annotation which indicates that this class is a service component in Spring

@Service
@RequiredArgsConstructor
@Slf4j

public class CustomUserDetailsService implements UserDetailsService{
    
    private final UserRepository userRepository;

    @Override
// method to load user details by username (email in this case) for authentication
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
    log.info("Attempting to load user by email: {}", email);

    User user = userRepository.findByEmail(email).orElseThrow(() -> { 
    log.warn("User not found with email: {}", email);
    return new UsernameNotFoundException("User not found with email: " + email );
    });
    
    log.info("User found: {} (ID: {}, Role: {})",email, user.getId(), user.getRole()); // log the user details for debugging purposes
    return new CustomUserDetails(user);
    }

    // method to load user details by email for OAuth2 authentication
    public UserDetails loadUserByEmailForOAuth(String email) throws UsernameNotFoundException {
    log.info("Loading user by email for OAuth: {}", email);
        
    User user = userRepository.findByEmail(email) .orElseThrow(() -> {
    log.warn("User not found for OAuth with email: {}", email);
    return new UsernameNotFoundException(
    "User not found with email: " + email);
            });

    log.info("OAuth user found: {} (ID: {})", email, user.getId());
    return new CustomUserDetails(user);
    }
}

