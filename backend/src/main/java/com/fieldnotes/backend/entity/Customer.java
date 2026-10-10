package com.fieldnotes.backend.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.persistence.Column;

@Entity
@Table(name = "customers")
public class Customer extends SyncableEntity {

    @Column(nullable = false)
    private String name;

    @Column(name = "contact_information")
    private String contactInformation;

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getContactInformation() { return contactInformation; }
    public void setContactInformation(String contactInformation) { this.contactInformation = contactInformation; }
}

