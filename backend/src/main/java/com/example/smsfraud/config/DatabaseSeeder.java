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
import org.springframework.transaction.annotation.Transactional;
import org.springframework.beans.factory.annotation.Value;

@Component
public class DatabaseSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DatabaseSeeder.class);

    private final UserRepository userRepository;
    private final UserRoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final boolean adminSeedEnabled;
    private final String adminEmail;
    private final String adminPhone;
    private final String adminPassword;

    public DatabaseSeeder(UserRepository userRepository,
                          UserRoleRepository roleRepository,
                          PasswordEncoder passwordEncoder,
                          @Value("${app.seed-admin.enabled:false}") boolean adminSeedEnabled,
                          @Value("${app.seed-admin.email:}") String adminEmail,
                          @Value("${app.seed-admin.phone:}") String adminPhone,
                          @Value("${app.seed-admin.password:}") String adminPassword) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.adminSeedEnabled = adminSeedEnabled;
        this.adminEmail = adminEmail;
        this.adminPhone = adminPhone;
        this.adminPassword = adminPassword;
    }

    @Override
    @Transactional
    public void run(String... args) {
        seedRoles();
        if (adminSeedEnabled) {
            seedAdminUser();
        }
    }

    private void seedRoles() {
        if (roleRepository.findByRoleName("USER").isEmpty()) {
            UserRole userRole = new UserRole();
            userRole.setRoleName("USER");
            roleRepository.save(userRole);
            log.info("Seeded USER role.");
        }
        if (roleRepository.findByRoleName("ADMIN").isEmpty()) {
            UserRole adminRole = new UserRole();
            adminRole.setRoleName("ADMIN");
            roleRepository.save(adminRole);
            log.info("Seeded ADMIN role.");
        }
    }

    private void seedAdminUser() {
        if (adminEmail.isBlank() || adminPhone.isBlank() || adminPassword.length() < 12) {
            throw new IllegalStateException(
                    "ADMIN_EMAIL, ADMIN_PHONE and an ADMIN_PASSWORD of at least 12 characters are required " +
                            "when ADMIN_SEED_ENABLED=true");
        }
        if (userRepository.findByEmail(adminEmail).isEmpty()) {
            UserRole adminRole = roleRepository.findByRoleName("ADMIN").orElseThrow();

            User admin = new User();
            admin.setEmail(adminEmail);
            admin.setPhone(adminPhone);
            admin.setFullName("System Administrator");
            admin.setPasswordHash(passwordEncoder.encode(adminPassword));
            admin.setRole(adminRole);
            admin.setVerified(true); // Auto verify admin
            admin.setActive(true);

            userRepository.save(admin);
            log.info("Seeded admin user: {}", adminEmail);
        }
    }
}
