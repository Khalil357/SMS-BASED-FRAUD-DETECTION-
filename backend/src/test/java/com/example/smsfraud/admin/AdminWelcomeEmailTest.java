package com.example.smsfraud.admin;

import com.example.smsfraud.admin.dto.CreateUserRequest;
import com.example.smsfraud.email.EmailService;
import com.example.smsfraud.scan.SmsScanRepository;
import com.example.smsfraud.sender.BlockedSenderRepository;
import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import com.example.smsfraud.user.UserRole;
import com.example.smsfraud.user.UserRoleRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AdminWelcomeEmailTest {
    @Test
    void creationEmailsInitialPasswordButPersistsOnlyItsHash() {
        UserRepository users = mock(UserRepository.class);
        UserRoleRepository roles = mock(UserRoleRepository.class);
        EmailService email = mock(EmailService.class);
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        UserRole role = new UserRole();
        role.setRoleName("ADMIN");
        when(roles.findByRoleName("ADMIN")).thenReturn(Optional.of(role));
        AdminServiceImpl service = new AdminServiceImpl(mock(SmsScanRepository.class),
                users, roles, mock(BlockedSenderRepository.class), encoder, email);
        String password = "Test<&Secret!42";

        var response = service.createUser(new CreateUserRequest(" New Admin ",
                " NEW-ADMIN@example.com ", "+255712345678", password, null));

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(users).save(saved.capture());
        assertNotEquals(password, saved.getValue().getPasswordHash());
        assertTrue(encoder.matches(password, saved.getValue().getPasswordHash()));
        assertFalse(saved.getValue().isVerified());
        assertEquals("ADMIN", response.role());
        verify(email).sendWelcomeEmail("new-admin@example.com", "New Admin", "ADMIN", password);
    }
}
