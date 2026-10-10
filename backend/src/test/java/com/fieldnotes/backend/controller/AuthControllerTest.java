package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.dto.SignupRequest;
import com.fieldnotes.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest
public class AuthControllerTest {

    @Autowired
    private AuthController authController;

    @Autowired
    private UserRepository userRepository;

    @BeforeEach
    public void setup() {
        userRepository.deleteAll();
    }

    @Test
    @Transactional
    public void testRegisterUser() {
        SignupRequest request = new SignupRequest();
        request.setEmail("test@test.com");
        request.setPassword("password");

        ResponseEntity<?> response = authController.registerUser(request);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(userRepository.findByEmail("test@test.com").orElse(null));
    }
}
