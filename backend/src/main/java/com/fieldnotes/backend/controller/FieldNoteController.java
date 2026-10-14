package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.entity.FieldNote;
import com.fieldnotes.backend.entity.MediaMetadata;
import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.repository.FieldNoteRepository;
import com.fieldnotes.backend.repository.MediaMetadataRepository;
import com.fieldnotes.backend.repository.SiteRepository;
import com.fieldnotes.backend.service.AuthenticatedUserService;
import com.fieldnotes.backend.service.PrivateMediaStorage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/notes")
public class FieldNoteController {

    @Autowired
    private FieldNoteRepository fieldNoteRepository;

    @Autowired
    private SiteRepository siteRepository;

    @Autowired
    private AuthenticatedUserService authenticatedUserService;

    @Autowired
    private MediaMetadataRepository mediaMetadataRepository;

    @Autowired
    private PrivateMediaStorage privateMediaStorage;

    @GetMapping
    public List<FieldNote> getAll() {
        return fieldNoteRepository.findByUserId(authenticatedUserService.getCurrentUserId());
    }

    @PostMapping
    public ResponseEntity<FieldNote> create(@RequestBody FieldNote note) {
        User user = authenticatedUserService.getCurrentUser();
        if (note.getSite() == null || note.getSite().getId() == null) {
            return ResponseEntity.badRequest().build();
        }
        return siteRepository.findByIdAndUserId(note.getSite().getId(), user.getId()).map(site -> {
            note.setUser(user);
            if (note.getId() == null) {
                note.setId(UUID.randomUUID());
            }
            note.setSite(site);
            return ResponseEntity.ok(fieldNoteRepository.save(note));
        }).orElse(ResponseEntity.badRequest().build());
    }

    @GetMapping("/{id}")
    public ResponseEntity<FieldNote> getById(@PathVariable UUID id) {
        return fieldNoteRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId())
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<FieldNote> update(@PathVariable UUID id, @RequestBody FieldNote noteDetails) {
        return fieldNoteRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId()).map(note -> {
            note.setTitle(noteDetails.getTitle());
            note.setDescription(noteDetails.getDescription());
            note.setStatus(noteDetails.getStatus());
            note.setLat(noteDetails.getLat());
            note.setLng(noteDetails.getLng());
            note.setRecordedAt(noteDetails.getRecordedAt());
            return ResponseEntity.ok(fieldNoteRepository.save(note));
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        return fieldNoteRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId()).map(note -> {
            note.setDeletedAt(OffsetDateTime.now());
            fieldNoteRepository.save(note);
            return ResponseEntity.ok().<Void>build();
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/photo")
    @Transactional
    public ResponseEntity<Void> uploadPhoto(
        @PathVariable UUID id,
        @RequestParam("file") MultipartFile file
    ) {
        UUID userId = authenticatedUserService.getCurrentUserId();
        FieldNote note = fieldNoteRepository.findByIdAndUserId(id, userId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        if (file.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Photo file is empty.");

        User user = authenticatedUserService.getCurrentUser();
        String originalName = file.getOriginalFilename() == null ? "photo" : file.getOriginalFilename();
        String safeName = java.nio.file.Paths.get(originalName).getFileName().toString();
        String extension = safeName.lastIndexOf('.') >= 0 ? safeName.substring(safeName.lastIndexOf('.')) : "";
        String storagePath = userId + "/" + id + "/" + UUID.randomUUID() + extension;
        String contentType = file.getContentType() == null ? MediaType.APPLICATION_OCTET_STREAM_VALUE : file.getContentType();
        try {
            privateMediaStorage.upload(storagePath, contentType, file.getBytes());
        } catch (IOException exception) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Could not read uploaded photo.");
        }

        note.setPhotoPath(storagePath);
        fieldNoteRepository.save(note);
        MediaMetadata metadata = new MediaMetadata();
        metadata.setId(UUID.randomUUID());
        metadata.setUser(user);
        metadata.setFieldNote(note);
        metadata.setStoragePath(storagePath);
        metadata.setFileName(safeName);
        metadata.setMimeType(contentType);
        metadata.setFileSize(file.getSize());
        metadata.setCreatedAt(OffsetDateTime.now());
        mediaMetadataRepository.save(metadata);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}/photo")
    public ResponseEntity<byte[]> getPhoto(@PathVariable UUID id) {
        UUID userId = authenticatedUserService.getCurrentUserId();
        FieldNote note = fieldNoteRepository.findByIdAndUserId(id, userId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        MediaMetadata metadata = mediaMetadataRepository
            .findFirstByFieldNoteIdAndUserIdOrderByCreatedAtDesc(id, userId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        byte[] content = privateMediaStorage.download(metadata.getStoragePath());
        MediaType mediaType = MediaType.APPLICATION_OCTET_STREAM;
        if (metadata.getMimeType() != null) {
            try {
                mediaType = MediaType.parseMediaType(metadata.getMimeType());
            } catch (IllegalArgumentException ignored) {
                mediaType = MediaType.APPLICATION_OCTET_STREAM;
            }
        }
        return ResponseEntity.ok()
            .contentType(mediaType)
            .body(content);
    }
}
