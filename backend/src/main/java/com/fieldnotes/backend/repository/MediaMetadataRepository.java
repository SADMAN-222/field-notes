package com.fieldnotes.backend.repository;

import com.fieldnotes.backend.entity.MediaMetadata;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.UUID;

public interface MediaMetadataRepository extends JpaRepository<MediaMetadata, UUID> {
    Optional<MediaMetadata> findFirstByFieldNoteIdAndUserIdOrderByCreatedAtDesc(UUID noteId, UUID userId);
}
