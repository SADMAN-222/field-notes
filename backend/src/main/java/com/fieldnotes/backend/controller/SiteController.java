package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.entity.Site;
import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.repository.CustomerRepository;
import com.fieldnotes.backend.repository.SiteRepository;
import com.fieldnotes.backend.service.AuthenticatedUserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/sites")
public class SiteController {

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private AuthenticatedUserService authenticatedUserService;

    @GetMapping
    public List<Site> getAll() {
        return siteRepository.findByUserId(authenticatedUserService.getCurrentUserId());
    }

    @PostMapping
    public ResponseEntity<Site> create(@RequestBody Site site) {
        User user = authenticatedUserService.getCurrentUser();
        if (site.getCustomer() == null || site.getCustomer().getId() == null) {
            return ResponseEntity.badRequest().build();
        }
        return customerRepository.findByIdAndUserId(site.getCustomer().getId(), user.getId()).map(customer -> {
            site.setUser(user);
            if (site.getId() == null) {
                site.setId(UUID.randomUUID());
            }
            site.setCustomer(customer);
            return ResponseEntity.ok(siteRepository.save(site));
        }).orElse(ResponseEntity.badRequest().build());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Site> getById(@PathVariable UUID id) {
        return siteRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId())
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<Site> update(@PathVariable UUID id, @RequestBody Site siteDetails) {
        return siteRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId()).map(site -> {
            site.setSiteName(siteDetails.getSiteName());
            site.setAddress(siteDetails.getAddress());
            return ResponseEntity.ok(siteRepository.save(site));
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        return siteRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId()).map(site -> {
            site.setDeletedAt(OffsetDateTime.now());
            siteRepository.save(site);
            return ResponseEntity.ok().<Void>build();
        }).orElse(ResponseEntity.notFound().build());
    }
}
