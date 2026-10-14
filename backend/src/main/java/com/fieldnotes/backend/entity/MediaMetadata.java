package com.fieldnotes.backend.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "media_metadata")
public class MediaMetadata {
    @Id
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "field_note_id")
    private FieldNote fieldNote;

    @Column(name = "storage_path", nullable = false, length = 500)
    private String storagePath;

    @Column(name = "file_name")
    private String fileName;

    @Column(name = "mime_type")
    private String mimeType;

    @Column(name = "file_size")
    private Long fileSize;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
    public FieldNote getFieldNote() { return fieldNote; }
    public void setFieldNote(FieldNote fieldNote) { this.fieldNote = fieldNote; }
    public String getStoragePath() { return storagePath; }
    public void setStoragePath(String storagePath) { this.storagePath = storagePath; }
    public String getFileName() { return fileName; }
    public void setFileName(String fileName) { this.fileName = fileName; }
    public String getMimeType() { return mimeType; }
    public void setMimeType(String mimeType) { this.mimeType = mimeType; }
    public Long getFileSize() { return fileSize; }
    public void setFileSize(Long fileSize) { this.fileSize = fileSize; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}
