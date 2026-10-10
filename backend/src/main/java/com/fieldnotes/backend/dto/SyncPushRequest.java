package com.fieldnotes.backend.dto;

import com.fieldnotes.backend.entity.Customer;
import com.fieldnotes.backend.entity.FieldNote;
import com.fieldnotes.backend.entity.Site;
import java.util.List;

public class SyncPushRequest {
    private List<Customer> customers;
    private List<Site> sites;
    private List<FieldNote> fieldNotes;

    public List<Customer> getCustomers() { return customers; }
    public void setCustomers(List<Customer> customers) { this.customers = customers; }
    public List<Site> getSites() { return sites; }
    public void setSites(List<Site> sites) { this.sites = sites; }
    public List<FieldNote> getFieldNotes() { return fieldNotes; }
    public void setFieldNotes(List<FieldNote> fieldNotes) { this.fieldNotes = fieldNotes; }
}
