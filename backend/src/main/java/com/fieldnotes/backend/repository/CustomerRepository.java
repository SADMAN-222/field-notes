package com.fieldnotes.backend.repository;

import com.fieldnotes.backend.entity.Customer;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CustomerRepository extends JpaRepository<Customer, UUID> {
    List<Customer> findByUserId(UUID userId);
    Optional<Customer> findByIdAndUserId(UUID id, UUID userId);
}
