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

@Component
public class DatabaseSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DatabaseSeeder.class);

    private final UserRepository userRepository;
    private final UserRoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;

    public DatabaseSeeder(UserRepository userRepository,
                          UserRoleRepository roleRepository,
                          PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
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
        String adminEmail = "james06alexander@gmail.com";
        if (userRepository.findByEmail(adminEmail).isEmpty()) {
            UserRole adminRole = roleRepository.findByRoleName("ADMIN").orElseThrow();

            User admin = new User();
            admin.setEmail(adminEmail);
            admin.setPhone("+00000000001"); // Admins might not need a phone, but it's unique
            admin.setFullName("System Administrator");
            admin.setPasswordHash(passwordEncoder.encode("admin123"));
            admin.setRole(adminRole);
            admin.setVerified(true); // Auto verify admin
            admin.setActive(true);

            userRepository.save(admin);
            log.info("Seeded admin user: james06alexander@gmail.com / admin123");
        }
    }
}
