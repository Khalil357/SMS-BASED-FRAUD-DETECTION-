package com.example.smsfraud.config;

import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import com.example.smsfraud.user.UserRole;
import com.example.smsfraud.user.UserRoleRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class DatabaseSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DatabaseSeeder.class);

    private final UserRepository userRepository;
    private final UserRoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;

    // Initial admin credentials, supplied via environment variables (SEED_ADMIN_*).
    // Intentionally blank by default so no credentials are hardcoded in source.
    private final String seedAdminEmail;
    private final String seedAdminPassword;
    private final String seedAdminFullName;
    private final String seedAdminPhone;

    public DatabaseSeeder(UserRepository userRepository,
                          UserRoleRepository roleRepository,
                          PasswordEncoder passwordEncoder,
                          @Value("${admin.seed.email:}") String seedAdminEmail,
                          @Value("${admin.seed.password:}") String seedAdminPassword,
                          @Value("${admin.seed.full-name:}") String seedAdminFullName,
                          @Value("${admin.seed.phone:}") String seedAdminPhone) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.seedAdminEmail = seedAdminEmail;
        this.seedAdminPassword = seedAdminPassword;
        this.seedAdminFullName = seedAdminFullName;
        this.seedAdminPhone = seedAdminPhone;
    }

    @Override
    @Transactional
    public void run(String... args) {
        seedRoles();
        seedAdminUser();
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
        if (seedAdminEmail == null || seedAdminEmail.isBlank()
                || seedAdminPassword == null || seedAdminPassword.isBlank()) {
            log.info("Skipping admin seed: set SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD "
                    + "to create the initial admin account.");
            return;
        }

        if (userRepository.findByEmail(seedAdminEmail).isPresent()) {
            log.info("Admin {} already exists; skipping seed.", seedAdminEmail);
            return;
        }

        UserRole adminRole = roleRepository.findByRoleName("ADMIN").orElseThrow();

        User admin = new User();
        admin.setEmail(seedAdminEmail);
        // Phone is optional for the seeded admin (login is by email). Leave null
        // when not provided rather than a fake value that collides with other seeds.
        if (seedAdminPhone != null && !seedAdminPhone.isBlank()) {
            admin.setPhone(seedAdminPhone);
        }
        admin.setFullName(seedAdminFullName == null || seedAdminFullName.isBlank()
                ? "System Administrator" : seedAdminFullName);
        admin.setPasswordHash(passwordEncoder.encode(seedAdminPassword));
        admin.setRole(adminRole);
        admin.setVerified(true); // Auto-verify the seeded admin
        admin.setActive(true);

        userRepository.save(admin);
        log.info("Seeded admin user: {}", seedAdminEmail);
    }
}
