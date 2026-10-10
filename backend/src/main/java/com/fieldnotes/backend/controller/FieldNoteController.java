package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.entity.FieldNote;
import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.repository.FieldNoteRepository;
import com.fieldnotes.backend.repository.SiteRepository;
import com.fieldnotes.backend.repository.UserRepository;
import com.fieldnotes.backend.security.UserDetailsImpl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/notes")
public class FieldNoteController {
    @Autowired private FieldNoteRepository fieldNoteRepository;
    @Autowired private SiteRepository siteRepository;
    @Autowired private UserRepository userRepository;

    @Value("${upload.dir}")
    private String uploadDir;

    private User getCurrentUser() {
        UserDetailsImpl userDetails = (UserDetailsImpl) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        return userRepository.findById(userDetails.getId()).orElseThrow();
    }

    @GetMapping
    public List<FieldNote> getAll() {
        return fieldNoteRepository.findByUserId(getCurrentUser().getId());
    }

    @PostMapping
    public ResponseEntity<FieldNote> create(@RequestBody FieldNote note) {
        User user = getCurrentUser();
        return siteRepository.findByIdAndUserId(note.getSite().getId(), user.getId()).map(site -> {
            note.setUser(user);
            note.setId(UUID.randomUUID());
            note.setSite(site);
            return ResponseEntity.ok(fieldNoteRepository.save(note));
        }).orElse(ResponseEntity.badRequest().build());
    }

    @GetMapping("/{id}")
    public ResponseEntity<FieldNote> getById(@PathVariable UUID id) {
        return fieldNoteRepository.findByIdAndUserId(id, getCurrentUser().getId())
                .map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<FieldNote> update(@PathVariable UUID id, @RequestBody FieldNote noteDetails) {
        return fieldNoteRepository.findByIdAndUserId(id, getCurrentUser().getId()).map(note -> {
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
        return fieldNoteRepository.findByIdAndUserId(id, getCurrentUser().getId()).map(note -> {
            note.setDeletedAt(OffsetDateTime.now());
            fieldNoteRepository.save(note);
            return ResponseEntity.ok().<Void>build();
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/photo")
    public ResponseEntity<String> uploadPhoto(@PathVariable UUID id, @RequestParam("file") MultipartFile file) {
        return fieldNoteRepository.findByIdAndUserId(id, getCurrentUser().getId()).map(note -> {
            try {
                Path uploadPath = Paths.get(uploadDir);
                if (!Files.exists(uploadPath)) {
                    Files.createDirectories(uploadPath);
                }
                String filename = id.toString() + "_" + file.getOriginalFilename();
                Path filePath = uploadPath.resolve(filename);
                Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);

                note.setPhotoPath(filename);
                fieldNoteRepository.save(note);
                return ResponseEntity.ok("File uploaded successfully: " + filename);
            } catch (IOException e) {
                return ResponseEntity.internalServerError().body("Could not upload the file: " + e.getMessage());
            }
        }).orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/photo")
    public ResponseEntity<Resource> getPhoto(@PathVariable UUID id) {
        return fieldNoteRepository.findByIdAndUserId(id, getCurrentUser().getId()).<ResponseEntity<Resource>>map(note -> {
            try {
                if (note.getPhotoPath() == null) return ResponseEntity.notFound().build();
                Path filePath = Paths.get(uploadDir).resolve(note.getPhotoPath()).normalize();
                Resource resource = new UrlResource(filePath.toUri());
                if (resource.exists()) {
                    return ResponseEntity.ok()
                            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + resource.getFilename() + "\"")
                            .body(resource);
                } else {
                    return ResponseEntity.notFound().build();
                }
            } catch (MalformedURLException e) {
                return ResponseEntity.status(500).build();
            }
        }).orElse(ResponseEntity.notFound().build());
    }
}
