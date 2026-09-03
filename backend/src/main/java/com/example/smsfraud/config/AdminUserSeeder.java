package com.example.smsfraud.config;

import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import com.example.smsfraud.user.UserRole;
import com.example.smsfraud.user.UserRoleRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
public class AdminUserSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminUserSeeder.class);

    private final UserRepository userRepository;
    private final UserRoleRepository userRoleRepository;
    private final PasswordEncoder passwordEncoder;

    public AdminUserSeeder(UserRepository userRepository,
                           UserRoleRepository userRoleRepository,
                           PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.userRoleRepository = userRoleRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        final String adminEmail = "smsfraud.noreply@gmail.com";
        if (!userRepository.existsByEmail(adminEmail)) {
            UserRole adminRole = userRoleRepository.findByRoleName("ADMIN")
                    .orElseGet(() -> {
                        UserRole newRole = new UserRole();
                        newRole.setRoleName("ADMIN");
                        return userRoleRepository.save(newRole);
                    });

            User admin = new User();
            admin.setFullName("Argus System Administrator");
            admin.setEmail(adminEmail);
            admin.setPhone("+255746046202");
            admin.setGender("Male");
            admin.setPasswordHash(passwordEncoder.encode("Admin000!"));
            admin.setRole(adminRole);
            admin.setVerified(true);
            admin.setActive(true);
            admin.setLocked(false);

            userRepository.save(admin);
            log.info("Successfully seeded hardcoded Admin user: [{}] into PostgreSQL database.", adminEmail);
        } else {
            userRepository.findByEmail(adminEmail).ifPresent(user -> {
                user.setPasswordHash(passwordEncoder.encode("Admin000!"));
                user.setVerified(true);
                user.setActive(true);
                user.setLocked(false);
                userRepository.save(user);
                log.info("Updated existing Admin user [{}] credentials in PostgreSQL database.", adminEmail);
            });
        }
    }
}
