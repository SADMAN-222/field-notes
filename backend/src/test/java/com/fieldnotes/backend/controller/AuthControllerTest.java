package com.fieldnotes.backend.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest
public class AuthControllerTest {

    @Autowired
    private AuthController authController;

    @Test
    public void testHealthEndpoint() {
        ResponseEntity<Map<String, String>> response = authController.health();
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("UP", response.getBody().get("status"));
        assertEquals("Supabase", response.getBody().get("authProvider"));
    }

    @Test
    public void testLogoutEndpoint() {
        var response = authController.logout();
        assertEquals(HttpStatus.OK, response.getStatusCode());
    }
}
