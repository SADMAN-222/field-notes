package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.dto.MessageResponse;
import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.service.AuthenticatedUserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    @Autowired
    private AuthenticatedUserService authenticatedUserService;

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP", "authProvider", "Supabase"));
    }

    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> getCurrentUser() {
        User user = authenticatedUserService.getCurrentUser();
        return ResponseEntity.ok(Map.of(
            "id", user.getId().toString(),
            "email", user.getEmail()
        ));
    }

    @PostMapping("/logout")
    public ResponseEntity<MessageResponse> logout() {
        return ResponseEntity.ok(new MessageResponse("Supabase session terminated"));
    }
}
