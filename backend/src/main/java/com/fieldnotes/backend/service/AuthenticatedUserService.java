package com.fieldnotes.backend.service;

import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class AuthenticatedUserService {

    @Autowired
    private UserRepository userRepository;

    public User getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null) {
            throw new IllegalStateException("No authentication found in security context");
        }

        UUID userId;
        String email = null;

        if (authentication.getPrincipal() instanceof Jwt jwt) {
            String subject = jwt.getSubject();
            try {
                userId = UUID.fromString(subject);
            } catch (IllegalArgumentException e) {
                throw new IllegalStateException("Invalid UUID format in JWT subject: " + subject, e);
            }
            email = jwt.getClaimAsString("email");
        } else if (authentication.getName() != null) {
            // Fallback for test principals / mock user
            try {
                userId = UUID.fromString(authentication.getName());
            } catch (IllegalArgumentException e) {
                // If username is not a UUID, generate a deterministic UUID
                userId = UUID.nameUUIDFromBytes(authentication.getName().getBytes());
                email = authentication.getName();
            }
        } else {
            throw new IllegalStateException("Unsupported principal type: " + authentication.getPrincipal().getClass());
        }

        if (email == null || email.isBlank()) {
            email = "user_" + userId.toString().substring(0, 8) + "@supabase.local";
        }

        final UUID finalUserId = userId;
        final String finalEmail = email;

        // Auto-provision user in public.users to maintain foreign key integrity
        return userRepository.findById(finalUserId).orElseGet(() -> {
            User newUser = new User(finalUserId, finalEmail);
            return userRepository.save(newUser);
        });
    }

    public UUID getCurrentUserId() {
        return getCurrentUser().getId();
    }
}

