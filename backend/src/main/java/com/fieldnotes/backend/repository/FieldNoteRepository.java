package com.fieldnotes.backend.repository;

import com.fieldnotes.backend.entity.FieldNote;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FieldNoteRepository extends JpaRepository<FieldNote, UUID> {
    List<FieldNote> findByUserId(UUID userId);
    Optional<FieldNote> findByIdAndUserId(UUID id, UUID userId);
}
