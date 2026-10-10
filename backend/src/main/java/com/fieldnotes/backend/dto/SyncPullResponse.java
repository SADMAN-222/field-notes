package com.fieldnotes.backend.dto;

import com.fieldnotes.backend.entity.Customer;
import com.fieldnotes.backend.entity.FieldNote;
import com.fieldnotes.backend.entity.Site;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public class SyncPullResponse {
    private List<Customer> customers;
    private List<Site> sites;
    private List<FieldNote> fieldNotes;
    private List<UUID> deletedCustomerIds;
    private List<UUID> deletedSiteIds;
    private List<UUID> deletedFieldNoteIds;
    private OffsetDateTime nextCursor;

    public List<Customer> getCustomers() { return customers; }
    public void setCustomers(List<Customer> customers) { this.customers = customers; }
    public List<Site> getSites() { return sites; }
    public void setSites(List<Site> sites) { this.sites = sites; }
    public List<FieldNote> getFieldNotes() { return fieldNotes; }
    public void setFieldNotes(List<FieldNote> fieldNotes) { this.fieldNotes = fieldNotes; }
    public List<UUID> getDeletedCustomerIds() { return deletedCustomerIds; }
    public void setDeletedCustomerIds(List<UUID> deletedCustomerIds) { this.deletedCustomerIds = deletedCustomerIds; }
    public List<UUID> getDeletedSiteIds() { return deletedSiteIds; }
    public void setDeletedSiteIds(List<UUID> deletedSiteIds) { this.deletedSiteIds = deletedSiteIds; }
    public List<UUID> getDeletedFieldNoteIds() { return deletedFieldNoteIds; }
    public void setDeletedFieldNoteIds(List<UUID> deletedFieldNoteIds) { this.deletedFieldNoteIds = deletedFieldNoteIds; }
    public OffsetDateTime getNextCursor() { return nextCursor; }
    public void setNextCursor(OffsetDateTime nextCursor) { this.nextCursor = nextCursor; }
}
