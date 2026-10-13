package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.dto.SyncPullResponse;
import com.fieldnotes.backend.dto.SyncPushRequest;
import com.fieldnotes.backend.entity.*;
import com.fieldnotes.backend.repository.*;
import com.fieldnotes.backend.service.AuthenticatedUserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/sync")
public class SyncController {

    @Autowired private SyncChangeRepository syncChangeRepository;
    @Autowired private CustomerRepository customerRepository;
    @Autowired private SiteRepository siteRepository;
    @Autowired private FieldNoteRepository fieldNoteRepository;
    @Autowired private AuthenticatedUserService authenticatedUserService;

    @PostMapping("/push")
    @Transactional
    public ResponseEntity<Void> push(@RequestBody SyncPushRequest request) {
        User user = authenticatedUserService.getCurrentUser();
        OffsetDateTime now = OffsetDateTime.now();

        if (request.getCustomers() != null) {
            for (Customer c : request.getCustomers()) {
                c.setUser(user);
                c.setUpdatedAt(now);
                if (c.getCreatedAt() == null) c.setCreatedAt(now);
                customerRepository.save(c);
                recordChange(user, "customer", c.getId(), c.getDeletedAt() != null ? "DELETE" : "UPSERT", c.getVersion());
            }
        }
        if (request.getSites() != null) {
            for (Site s : request.getSites()) {
                if (s.getCustomer() == null || s.getCustomer().getId() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Site customer is required.");
                }
                Customer customer = customerRepository
                    .findByIdAndUserId(s.getCustomer().getId(), user.getId())
                    .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Site customer does not exist for the authenticated user."
                    ));
                s.setUser(user);
                s.setCustomer(customer);
                s.setUpdatedAt(now);
                if (s.getCreatedAt() == null) s.setCreatedAt(now);
                siteRepository.save(s);
                recordChange(user, "site", s.getId(), s.getDeletedAt() != null ? "DELETE" : "UPSERT", s.getVersion());
            }
        }
        if (request.getFieldNotes() != null) {
            for (FieldNote fn : request.getFieldNotes()) {
                if (fn.getSite() == null || fn.getSite().getId() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Field note site is required.");
                }
                Site site = siteRepository
                    .findByIdAndUserId(fn.getSite().getId(), user.getId())
                    .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Field note site does not exist for the authenticated user."
                    ));
                fn.setUser(user);
                fn.setSite(site);
                fn.setUpdatedAt(now);
                if (fn.getCreatedAt() == null) fn.setCreatedAt(now);
                fieldNoteRepository.save(fn);
                recordChange(user, "fieldNote", fn.getId(), fn.getDeletedAt() != null ? "DELETE" : "UPSERT", fn.getVersion());
            }
        }
        return ResponseEntity.ok().build();
    }

    private void recordChange(User user, String type, UUID entityId, String operation, Long version) {
        SyncChange sc = new SyncChange();
        sc.setUser(user);
        sc.setEntityType(type);
        sc.setEntityId(entityId);
        sc.setOperation(operation);
        sc.setTimestamp(OffsetDateTime.now());
        sc.setVersion(version != null ? version : 1L);
        syncChangeRepository.save(sc);
    }

    @GetMapping("/pull")
    public ResponseEntity<SyncPullResponse> pull(@RequestParam(required = false) OffsetDateTime cursor) {
        User user = authenticatedUserService.getCurrentUser();
        if (cursor == null) {
            cursor = OffsetDateTime.parse("1970-01-01T00:00:00Z");
        }

        List<SyncChange> changes = syncChangeRepository.findByUserIdAndTimestampGreaterThanOrderByTimestampAsc(user.getId(), cursor);

        SyncPullResponse response = new SyncPullResponse();
        response.setCustomers(new ArrayList<>());
        response.setSites(new ArrayList<>());
        response.setFieldNotes(new ArrayList<>());
        response.setDeletedCustomerIds(new ArrayList<>());
        response.setDeletedSiteIds(new ArrayList<>());
        response.setDeletedFieldNoteIds(new ArrayList<>());

        OffsetDateTime nextCursor = cursor;

        for (SyncChange change : changes) {
            if ("customer".equals(change.getEntityType())) {
                if ("DELETE".equals(change.getOperation())) {
                    response.getDeletedCustomerIds().add(change.getEntityId());
                } else {
                    customerRepository.findByIdAndUserId(change.getEntityId(), user.getId()).ifPresent(response.getCustomers()::add);
                }
            } else if ("site".equals(change.getEntityType())) {
                if ("DELETE".equals(change.getOperation())) {
                    response.getDeletedSiteIds().add(change.getEntityId());
                } else {
                    siteRepository.findByIdAndUserId(change.getEntityId(), user.getId()).ifPresent(response.getSites()::add);
                }
            } else if ("fieldNote".equals(change.getEntityType())) {
                if ("DELETE".equals(change.getOperation())) {
                    response.getDeletedFieldNoteIds().add(change.getEntityId());
                } else {
                    fieldNoteRepository.findByIdAndUserId(change.getEntityId(), user.getId()).ifPresent(response.getFieldNotes()::add);
                }
            }
            if (change.getTimestamp().isAfter(nextCursor)) {
                nextCursor = change.getTimestamp();
            }
        }

        response.setNextCursor(nextCursor);
        return ResponseEntity.ok(response);
    }
}
