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
import java.util.*;

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
    public ResponseEntity<?> push(@RequestBody SyncPushRequest request) {
        User user = authenticatedUserService.getCurrentUser();
        OffsetDateTime now = OffsetDateTime.now();
        List<Map<String, Object>> conflicts = findConflicts(request, user);
        if (!conflicts.isEmpty()) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                "code", "SYNC_CONFLICT",
                "message", "Server changes were preserved. Local mutations remain available for resolution.",
                "conflicts", conflicts
            ));
        }

        if (request.getCustomers() != null) {
            for (Customer incoming : request.getCustomers()) {
                Customer current = customerRepository
                    .findByIdAndUserId(incoming.getId(), user.getId()).orElse(null);
                if (isReplay("customer", current, incoming)) continue;
                if (incoming.getCreatedAt() == null) incoming.setCreatedAt(now);
                incoming.setUser(user);
                if (current == null) {
                    incoming.setVersion(null);
                    Customer saved = customerRepository.save(incoming);
                    incoming.setVersion(saved.getVersion());
                } else {
                    current.setName(incoming.getName());
                    current.setContactInformation(incoming.getContactInformation());
                    current.setUpdatedAt(incoming.getUpdatedAt());
                    current.setDeletedAt(incoming.getDeletedAt());
                    customerRepository.save(current);
                }
                recordChange(user, "customer", incoming.getId(),
                    incoming.getDeletedAt() != null ? "DELETE" : "UPSERT", incoming.getVersion());
            }
        }
        if (request.getSites() != null) {
            for (Site incoming : request.getSites()) {
                if (incoming.getCustomer() == null || incoming.getCustomer().getId() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Site customer is required.");
                }
                Customer customer = customerRepository
                    .findByIdAndUserId(incoming.getCustomer().getId(), user.getId())
                    .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "Site customer does not exist for the authenticated user."
                    ));
                Site current = siteRepository.findByIdAndUserId(incoming.getId(), user.getId()).orElse(null);
                if (isReplay("site", current, incoming)) continue;
                if (incoming.getCreatedAt() == null) incoming.setCreatedAt(now);
                incoming.setUser(user);
                incoming.setCustomer(customer);
                if (current == null) {
                    incoming.setVersion(null);
                    Site saved = siteRepository.save(incoming);
                    incoming.setVersion(saved.getVersion());
                } else {
                    current.setCustomer(customer);
                    current.setSiteName(incoming.getSiteName());
                    current.setAddress(incoming.getAddress());
                    current.setUpdatedAt(incoming.getUpdatedAt());
                    current.setDeletedAt(incoming.getDeletedAt());
                    siteRepository.save(current);
                }
                recordChange(user, "site", incoming.getId(),
                    incoming.getDeletedAt() != null ? "DELETE" : "UPSERT", incoming.getVersion());
            }
        }
        if (request.getFieldNotes() != null) {
            for (FieldNote incoming : request.getFieldNotes()) {
                if (incoming.getSite() == null || incoming.getSite().getId() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Field note site is required.");
                }
                Site site = siteRepository
                    .findByIdAndUserId(incoming.getSite().getId(), user.getId())
                    .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "Field note site does not exist for the authenticated user."
                    ));
                FieldNote current = fieldNoteRepository
                    .findByIdAndUserId(incoming.getId(), user.getId()).orElse(null);
                if (isReplay("fieldNote", current, incoming)) continue;
                if (incoming.getCreatedAt() == null) incoming.setCreatedAt(now);
                incoming.setUser(user);
                incoming.setSite(site);
                if (current == null) {
                    incoming.setVersion(null);
                    FieldNote saved = fieldNoteRepository.save(incoming);
                    incoming.setVersion(saved.getVersion());
                } else {
                    current.setSite(site);
                    current.setTitle(incoming.getTitle());
                    current.setDescription(incoming.getDescription());
                    current.setStatus(incoming.getStatus());
                    current.setPhotoPath(incoming.getPhotoPath());
                    current.setLat(incoming.getLat());
                    current.setLng(incoming.getLng());
                    current.setRecordedAt(incoming.getRecordedAt());
                    current.setUpdatedAt(incoming.getUpdatedAt());
                    current.setDeletedAt(incoming.getDeletedAt());
                    fieldNoteRepository.save(current);
                }
                recordChange(user, "fieldNote", incoming.getId(),
                    incoming.getDeletedAt() != null ? "DELETE" : "UPSERT", incoming.getVersion());
            }
        }
        return ResponseEntity.ok().build();
    }

    private List<Map<String, Object>> findConflicts(SyncPushRequest request, User user) {
        List<Map<String, Object>> conflicts = new ArrayList<>();
        Map<String, Long> batchVersions = new HashMap<>();
        if (request.getCustomers() != null) {
            for (Customer item : request.getCustomers()) {
                inspect("customer", item, customerRepository.findById(item.getId()).orElse(null),
                    customerRepository.findByIdAndUserId(item.getId(), user.getId()).orElse(null),
                    batchVersions, conflicts);
            }
        }
        if (request.getSites() != null) {
            for (Site item : request.getSites()) {
                inspect("site", item, siteRepository.findById(item.getId()).orElse(null),
                    siteRepository.findByIdAndUserId(item.getId(), user.getId()).orElse(null),
                    batchVersions, conflicts);
            }
        }
        if (request.getFieldNotes() != null) {
            for (FieldNote item : request.getFieldNotes()) {
                inspect("fieldNote", item, fieldNoteRepository.findById(item.getId()).orElse(null),
                    fieldNoteRepository.findByIdAndUserId(item.getId(), user.getId()).orElse(null),
                    batchVersions, conflicts);
            }
        }
        return conflicts;
    }

    private void inspect(
        String type,
        SyncableEntity incoming,
        SyncableEntity record,
        SyncableEntity ownedRecord,
        Map<String, Long> batchVersions,
        List<Map<String, Object>> conflicts
    ) {
        String key = type + ":" + incoming.getId();
        if (record != null && ownedRecord == null) {
            conflicts.add(conflict(type, incoming.getId(), null));
            return;
        }

        Long currentVersion = batchVersions.containsKey(key)
            ? batchVersions.get(key)
            : record == null ? null : record.getVersion();
        long incomingVersion = incoming.getVersion() == null ? 0L : incoming.getVersion();
        if (currentVersion != null) {
            if (incomingVersion == currentVersion) {
                if (sameContent(type, ownedRecord, incoming)) {
                    batchVersions.put(key, currentVersion);
                    return;
                }
                conflicts.add(conflict(type, incoming.getId(), currentVersion));
                return;
            }
            if (incomingVersion != currentVersion + 1) {
                conflicts.add(conflict(type, incoming.getId(), currentVersion));
                return;
            }
        }
        batchVersions.put(key, incomingVersion);
    }

    private boolean isReplay(String type, SyncableEntity current, SyncableEntity incoming) {
        return current != null
            && Objects.equals(current.getVersion(), incoming.getVersion())
            && sameContent(type, current, incoming);
    }

    private boolean sameContent(String type, SyncableEntity current, SyncableEntity incoming) {
        if (current == null || !Objects.equals(current.getDeletedAt(), incoming.getDeletedAt())) return false;
        if ("customer".equals(type)) {
            Customer a = (Customer) current;
            Customer b = (Customer) incoming;
            return Objects.equals(a.getName(), b.getName())
                && Objects.equals(a.getContactInformation(), b.getContactInformation());
        }
        if ("site".equals(type)) {
            Site a = (Site) current;
            Site b = (Site) incoming;
            return Objects.equals(a.getSiteName(), b.getSiteName())
                && Objects.equals(a.getAddress(), b.getAddress())
                && a.getCustomer() != null && b.getCustomer() != null
                && Objects.equals(a.getCustomer().getId(), b.getCustomer().getId());
        }
        FieldNote a = (FieldNote) current;
        FieldNote b = (FieldNote) incoming;
        return Objects.equals(a.getTitle(), b.getTitle())
            && Objects.equals(a.getDescription(), b.getDescription())
            && Objects.equals(a.getStatus(), b.getStatus())
            && Objects.equals(a.getPhotoPath(), b.getPhotoPath())
            && Objects.equals(a.getLat(), b.getLat())
            && Objects.equals(a.getLng(), b.getLng())
            && Objects.equals(a.getRecordedAt(), b.getRecordedAt())
            && a.getSite() != null && b.getSite() != null
            && Objects.equals(a.getSite().getId(), b.getSite().getId());
    }

    private Map<String, Object> conflict(String type, UUID id, Long serverVersion) {
        return Map.of(
            "entityType", type,
            "entityId", id,
            "serverVersion", serverVersion == null ? -1L : serverVersion
        );
    }

    private void recordChange(User user, String type, UUID entityId, String operation, Long version) {
        SyncChange change = new SyncChange();
        change.setUser(user);
        change.setEntityType(type);
        change.setEntityId(entityId);
        change.setOperation(operation);
        change.setTimestamp(OffsetDateTime.now());
        change.setVersion(version != null ? version : 1L);
        syncChangeRepository.save(change);
    }

    @GetMapping("/pull")
    public ResponseEntity<SyncPullResponse> pull(@RequestParam(required = false) OffsetDateTime cursor) {
        User user = authenticatedUserService.getCurrentUser();
        if (cursor == null) cursor = OffsetDateTime.parse("1970-01-01T00:00:00Z");
        List<SyncChange> changes = syncChangeRepository
            .findByUserIdAndTimestampGreaterThanOrderByTimestampAsc(user.getId(), cursor);

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
                if ("DELETE".equals(change.getOperation())) response.getDeletedCustomerIds().add(change.getEntityId());
                else customerRepository.findByIdAndUserId(change.getEntityId(), user.getId())
                    .ifPresent(response.getCustomers()::add);
            } else if ("site".equals(change.getEntityType())) {
                if ("DELETE".equals(change.getOperation())) response.getDeletedSiteIds().add(change.getEntityId());
                else siteRepository.findByIdAndUserId(change.getEntityId(), user.getId())
                    .ifPresent(response.getSites()::add);
            } else if ("fieldNote".equals(change.getEntityType())) {
                if ("DELETE".equals(change.getOperation())) response.getDeletedFieldNoteIds().add(change.getEntityId());
                else fieldNoteRepository.findByIdAndUserId(change.getEntityId(), user.getId())
                    .ifPresent(response.getFieldNotes()::add);
            }
            if (change.getTimestamp().isAfter(nextCursor)) nextCursor = change.getTimestamp();
        }
        response.setNextCursor(nextCursor);
        return ResponseEntity.ok(response);
    }
}
