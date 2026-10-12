package com.fieldnotes.backend.controller;

import com.fieldnotes.backend.entity.Customer;
import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.repository.CustomerRepository;
import com.fieldnotes.backend.service.AuthenticatedUserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customers")
public class CustomerController {

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private AuthenticatedUserService authenticatedUserService;

    @GetMapping
    public List<Customer> getAll() {
        return customerRepository.findByUserId(authenticatedUserService.getCurrentUserId());
    }

    @PostMapping
    public Customer create(@RequestBody Customer customer) {
        User user = authenticatedUserService.getCurrentUser();
        customer.setUser(user);
        if (customer.getId() == null) {
            customer.setId(UUID.randomUUID());
        }
        return customerRepository.save(customer);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Customer> getById(@PathVariable UUID id) {
        return customerRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId())
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<Customer> update(@PathVariable UUID id, @RequestBody Customer customerDetails) {
        return customerRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId()).map(customer -> {
            customer.setName(customerDetails.getName());
            customer.setContactInformation(customerDetails.getContactInformation());
            return ResponseEntity.ok(customerRepository.save(customer));
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        return customerRepository.findByIdAndUserId(id, authenticatedUserService.getCurrentUserId()).map(customer -> {
            customer.setDeletedAt(OffsetDateTime.now());
            customerRepository.save(customer);
            return ResponseEntity.ok().<Void>build();
        }).orElse(ResponseEntity.notFound().build());
    }
}
