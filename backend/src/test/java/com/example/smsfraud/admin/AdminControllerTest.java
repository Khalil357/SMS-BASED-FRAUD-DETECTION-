package com.example.smsfraud.admin;

import com.example.smsfraud.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminControllerTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private AdminService adminService;

    @Test
    void listsAdministratorsAndMobileUsers() {
        when(userRepository.findAllWithRoles()).thenReturn(List.of());

        AdminController controller = new AdminController(userRepository, adminService);
        controller.listUsers();

        verify(userRepository).findAllWithRoles();
        verify(userRepository, never()).findAllAdminsWithRoles();
    }
}
