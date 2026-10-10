package com.fieldnotes.backend.repository;

import com.fieldnotes.backend.entity.SyncChange;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface SyncChangeRepository extends JpaRepository<SyncChange, UUID> {
    List<SyncChange> findByUserIdAndTimestampGreaterThanOrderByTimestampAsc(UUID userId, OffsetDateTime timestamp);
}
