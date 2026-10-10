package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.entity.Site;
import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.repository.SiteRepository;
import com.fieldnotes.backend.repository.UserRepository;
import com.fieldnotes.backend.repository.CustomerRepository;
import com.fieldnotes.backend.security.UserDetailsImpl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/sites")
public class SiteController {
    @Autowired private SiteRepository siteRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private CustomerRepository customerRepository;

    private User getCurrentUser() {
        UserDetailsImpl userDetails = (UserDetailsImpl) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        return userRepository.findById(userDetails.getId()).orElseThrow();
    }

    @GetMapping
    public List<Site> getAll() {
        return siteRepository.findByUserId(getCurrentUser().getId());
    }

    @PostMapping
    public ResponseEntity<Site> create(@RequestBody Site site) {
        User user = getCurrentUser();
        // Assuming site.getCustomer() is sent with the ID set
        return customerRepository.findByIdAndUserId(site.getCustomer().getId(), user.getId()).map(customer -> {
            site.setUser(user);
            site.setId(UUID.randomUUID());
            site.setCustomer(customer);
            return ResponseEntity.ok(siteRepository.save(site));
        }).orElse(ResponseEntity.badRequest().build());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Site> getById(@PathVariable UUID id) {
        return siteRepository.findByIdAndUserId(id, getCurrentUser().getId())
                .map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<Site> update(@PathVariable UUID id, @RequestBody Site siteDetails) {
        return siteRepository.findByIdAndUserId(id, getCurrentUser().getId()).map(site -> {
            site.setSiteName(siteDetails.getSiteName());
            site.setAddress(siteDetails.getAddress());
            return ResponseEntity.ok(siteRepository.save(site));
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        return siteRepository.findByIdAndUserId(id, getCurrentUser().getId()).map(site -> {
            site.setDeletedAt(OffsetDateTime.now());
            siteRepository.save(site);
            return ResponseEntity.ok().<Void>build();
        }).orElse(ResponseEntity.notFound().build());
    }
}
