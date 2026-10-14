package com.fieldnotes.backend.service;

public interface PrivateMediaStorage {
    void upload(String storagePath, String contentType, byte[] content);
    byte[] download(String storagePath);
}
