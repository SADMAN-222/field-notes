package com.fieldnotes.backend.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "sites")
public class Site extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @Column(name = "site_name", nullable = false)
    private String siteName;

    private String address;

    public Customer getCustomer() { return customer; }
    public void setCustomer(Customer customer) { this.customer = customer; }
    public String getSiteName() { return siteName; }
    public void setSiteName(String siteName) { this.siteName = siteName; }
    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }
}

