package com.fieldnotes.backend.repository;

import com.fieldnotes.backend.entity.Site;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SiteRepository extends JpaRepository<Site, UUID> {
    List<Site> findByUserId(UUID userId);
    Optional<Site> findByIdAndUserId(UUID id, UUID userId);
}
