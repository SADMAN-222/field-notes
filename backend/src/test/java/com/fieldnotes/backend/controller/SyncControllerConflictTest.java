package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.dto.SyncPushRequest;
import com.fieldnotes.backend.entity.Customer;
import com.fieldnotes.backend.entity.FieldNote;
import com.fieldnotes.backend.entity.Site;
import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.repository.CustomerRepository;
import com.fieldnotes.backend.repository.FieldNoteRepository;
import com.fieldnotes.backend.repository.MediaMetadataRepository;
import com.fieldnotes.backend.repository.SiteRepository;
import com.fieldnotes.backend.repository.UserRepository;
import com.fieldnotes.backend.service.PrivateMediaStorage;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.mock.web.MockMultipartFile;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@SpringBootTest
class SyncControllerConflictTest {
    @Autowired private SyncController syncController;
    @Autowired private FieldNoteController fieldNoteController;
    @Autowired private CustomerRepository customerRepository;
    @Autowired private SiteRepository siteRepository;
    @Autowired private FieldNoteRepository fieldNoteRepository;
    @Autowired private MediaMetadataRepository mediaMetadataRepository;
    @Autowired private UserRepository userRepository;
    @MockitoBean private PrivateMediaStorage privateMediaStorage;

    @AfterEach
    void clearAuthentication() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void syncPushCreatesClientVersionZeroCustomerSiteAndFieldNote() {
        UUID userId = UUID.randomUUID();
        UUID customerId = UUID.randomUUID();
        UUID siteId = UUID.randomUUID();
        UUID noteId = UUID.randomUUID();
        userRepository.saveAndFlush(new User(userId, "create-sync-test@example.invalid"));
        SecurityContextHolder.getContext().setAuthentication(
            new UsernamePasswordAuthenticationToken(userId.toString(), "", List.of())
        );

        Customer customer = new Customer();
        customer.setId(customerId);
        customer.setName("Synced Customer");
        customer.setVersion(0L);

        Customer siteCustomer = new Customer();
        siteCustomer.setId(customerId);
        Site site = new Site();
        site.setId(siteId);
        site.setCustomer(siteCustomer);
        site.setSiteName("Synced Site");
        site.setVersion(0L);

        Site noteSite = new Site();
        noteSite.setId(siteId);
        FieldNote note = new FieldNote();
        note.setId(noteId);
        note.setSite(noteSite);
        note.setTitle("Synced Note");
        note.setVersion(0L);

        SyncPushRequest request = new SyncPushRequest();
        request.setCustomers(List.of(customer));
        request.setSites(List.of(site));
        request.setFieldNotes(List.of(note));

        var response = syncController.push(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(0L, customerRepository.findByIdAndUserId(customerId, userId).orElseThrow().getVersion());
        assertEquals(0L, siteRepository.findByIdAndUserId(siteId, userId).orElseThrow().getVersion());
        assertEquals(0L, fieldNoteRepository.findByIdAndUserId(noteId, userId).orElseThrow().getVersion());

        var replay = syncController.push(request);
        assertEquals(HttpStatus.OK, replay.getStatusCode());
        assertEquals(0L, customerRepository.findByIdAndUserId(customerId, userId).orElseThrow().getVersion());
        assertEquals(0L, siteRepository.findByIdAndUserId(siteId, userId).orElseThrow().getVersion());
        assertEquals(0L, fieldNoteRepository.findByIdAndUserId(noteId, userId).orElseThrow().getVersion());
    }

    @Test
    void staleOfflineEditIsRejectedAndCanBeExplicitlyRebased() {
        UUID userId = UUID.randomUUID();
        UUID customerId = UUID.randomUUID();
        User user = userRepository.saveAndFlush(new User(userId, "sync-test@example.invalid"));
        SecurityContextHolder.getContext().setAuthentication(
            new UsernamePasswordAuthenticationToken(userId.toString(), "", List.of())
        );

        Customer serverRecord = new Customer();
        serverRecord.setId(customerId);
        serverRecord.setUser(user);
        serverRecord.setName("Initial");
        serverRecord.setCreatedAt(OffsetDateTime.now().minusDays(1));
        serverRecord.setUpdatedAt(OffsetDateTime.now().minusDays(1));
        serverRecord = customerRepository.saveAndFlush(serverRecord);
        for (int version = 0; version < 2; version++) {
            serverRecord.setName("Server version " + (version + 1));
            serverRecord.setUpdatedAt(OffsetDateTime.now());
            serverRecord = customerRepository.saveAndFlush(serverRecord);
        }
        long serverVersion = serverRecord.getVersion();
        assertEquals(2, serverVersion);

        Customer staleEdit = new Customer();
        staleEdit.setId(customerId);
        staleEdit.setName("Offline local edit");
        staleEdit.setUpdatedAt(OffsetDateTime.now());
        staleEdit.setVersion(serverVersion);
        SyncPushRequest staleRequest = new SyncPushRequest();
        staleRequest.setCustomers(List.of(staleEdit));

        var conflict = syncController.push(staleRequest);
        assertEquals(409, conflict.getStatusCode().value());
        assertEquals(
            "Server version " + serverVersion,
            customerRepository.findByIdAndUserId(customerId, userId).orElseThrow().getName()
        );

        staleEdit.setVersion(serverVersion + 1);
        SyncPushRequest rebasedRequest = new SyncPushRequest();
        rebasedRequest.setCustomers(List.of(staleEdit));
        var accepted = syncController.push(rebasedRequest);
        assertEquals(200, accepted.getStatusCode().value());
        Customer saved = customerRepository.findByIdAndUserId(customerId, userId).orElseThrow();
        assertEquals("Offline local edit", saved.getName());
        assertEquals(serverVersion + 1, saved.getVersion());
    }

    @Test
    void photoUploadStoresPrivateMetadataAndEnforcesNoteOwnershipOnDownload() {
        UUID userId = UUID.randomUUID();
        UUID noteId = UUID.randomUUID();
        User user = userRepository.saveAndFlush(new User(userId, "photo-test@example.invalid"));
        Customer customer = new Customer();
        customer.setId(UUID.randomUUID());
        customer.setUser(user);
        customer.setName("Photo Customer");
        customer = customerRepository.saveAndFlush(customer);
        Site site = new Site();
        site.setId(UUID.randomUUID());
        site.setUser(user);
        site.setCustomer(customer);
        site.setSiteName("Photo Site");
        site = siteRepository.saveAndFlush(site);
        FieldNote note = new FieldNote();
        note.setId(noteId);
        note.setUser(user);
        note.setSite(site);
        note.setTitle("Private photo test");
        note = fieldNoteRepository.saveAndFlush(note);

        SecurityContextHolder.getContext().setAuthentication(
            new UsernamePasswordAuthenticationToken(userId.toString(), "", List.of())
        );
        byte[] photoBytes = new byte[]{10, 20, 30};
        MockMultipartFile upload = new MockMultipartFile(
            "file", "../../inspection.jpg", "image/jpeg", photoBytes
        );
        when(privateMediaStorage.download(anyString())).thenReturn(photoBytes);

        var uploaded = fieldNoteController.uploadPhoto(noteId, upload);
        assertEquals(HttpStatus.NO_CONTENT, uploaded.getStatusCode());
        FieldNote savedNote = fieldNoteRepository.findByIdAndUserId(noteId, userId).orElseThrow();
        assertTrue(savedNote.getPhotoPath().startsWith(userId + "/" + noteId + "/"));
        var metadata = mediaMetadataRepository
            .findFirstByFieldNoteIdAndUserIdOrderByCreatedAtDesc(noteId, userId)
            .orElseThrow();
        assertEquals(savedNote.getPhotoPath(), metadata.getStoragePath());
        assertEquals("inspection.jpg", metadata.getFileName());
        assertArrayEquals(photoBytes, fieldNoteController.getPhoto(noteId).getBody());
        verify(privateMediaStorage).upload(
            eq(savedNote.getPhotoPath()), eq("image/jpeg"), eq(photoBytes)
        );

        UUID otherUserId = UUID.randomUUID();
        SecurityContextHolder.getContext().setAuthentication(
            new UsernamePasswordAuthenticationToken(otherUserId.toString(), "", List.of())
        );
        var denied = assertThrows(
            org.springframework.web.server.ResponseStatusException.class,
            () -> fieldNoteController.getPhoto(noteId)
        );
        assertEquals(HttpStatus.NOT_FOUND, denied.getStatusCode());
        verify(privateMediaStorage, times(1)).download(anyString());
    }
}
