package com.fieldnotes.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.regex.Pattern;

@Service
public class SupabasePrivateMediaStorage implements PrivateMediaStorage {
    private final String projectUrl;
    private final String serviceKey;
    private final String bucket;
    private final HttpClient httpClient;
    private volatile boolean privateBucketReady;

    public SupabasePrivateMediaStorage(
        @Value("${supabase.url:}") String projectUrl,
        @Value("${supabase.storage.service-key:}") String serviceKey,
        @Value("${supabase.storage.bucket:field-note-photos}") String bucket
    ) {
        this.projectUrl = projectUrl == null ? "" : projectUrl.replaceAll("/+$", "");
        this.serviceKey = serviceKey == null ? "" : serviceKey;
        this.bucket = bucket;
        if (!this.bucket.matches("[a-z0-9][a-z0-9_-]{1,61}")) {
            throw new IllegalArgumentException("Supabase Storage bucket name is invalid.");
        }
        this.httpClient = HttpClient.newBuilder().build();
    }

    @Override
    public void upload(String storagePath, String contentType, byte[] content) {
        ensurePrivateBucket();
        HttpRequest request = request(storagePath)
            .header("Content-Type", contentType == null ? "application/octet-stream" : contentType)
            .header("x-upsert", "true")
            .PUT(HttpRequest.BodyPublishers.ofByteArray(content))
            .build();
        send(request, HttpResponse.BodyHandlers.discarding());
    }

    @Override
    public byte[] download(String storagePath) {
        ensurePrivateBucket();
        HttpRequest request = request(storagePath).GET().build();
        return send(request, HttpResponse.BodyHandlers.ofByteArray()).body();
    }

    private void ensurePrivateBucket() {
        if (privateBucketReady) return;
        synchronized (this) {
            if (privateBucketReady) return;
            HttpRequest inspect = request("")
                .uri(URI.create(projectUrl + "/storage/v1/bucket/" + encodeSegment(bucket)))
                .GET()
                .build();
            HttpResponse<String> current = sendRaw(inspect, HttpResponse.BodyHandlers.ofString());
            if (current.statusCode() == 200) {
                requirePrivate(current.body());
                privateBucketReady = true;
                return;
            }
            if (current.statusCode() != 404) {
                throw storageError(current.statusCode());
            }

            String json = "{\"id\":\"" + bucket + "\",\"name\":\"" + bucket + "\",\"public\":false}";
            HttpRequest create = request("")
                .uri(URI.create(projectUrl + "/storage/v1/bucket"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();
            HttpResponse<String> created = sendRaw(create, HttpResponse.BodyHandlers.ofString());
            if (created.statusCode() == 200 || created.statusCode() == 201) {
                privateBucketReady = true;
                return;
            }
            if (created.statusCode() == 409) {
                HttpResponse<String> existing = sendRaw(inspect, HttpResponse.BodyHandlers.ofString());
                if (existing.statusCode() == 200) {
                    requirePrivate(existing.body());
                    privateBucketReady = true;
                    return;
                }
            }
            throw storageError(created.statusCode());
        }
    }

    private void requirePrivate(String response) {
        if (!Pattern.compile("\"public\"\\s*:\\s*false").matcher(response).find()) {
            throw new ResponseStatusException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "The configured Supabase photo bucket is public. Make it private before using photo sync."
            );
        }
    }

    private HttpRequest.Builder request(String storagePath) {
        if (projectUrl.isBlank() || serviceKey.isBlank()) {
            throw new ResponseStatusException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "Private photo storage is not configured on the backend."
            );
        }
        String encodedBucket = encodeSegment(bucket);
        String encodedPath = java.util.Arrays.stream(storagePath.split("/"))
            .map(this::encodeSegment)
            .collect(java.util.stream.Collectors.joining("/"));
        return HttpRequest.newBuilder()
            .uri(URI.create(projectUrl + "/storage/v1/object/" + encodedBucket + "/" + encodedPath))
            .header("Authorization", "Bearer " + serviceKey)
            .header("apikey", serviceKey);
    }

    private String encodeSegment(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
    }

    private <T> HttpResponse<T> send(HttpRequest request, HttpResponse.BodyHandler<T> handler) {
        HttpResponse<T> response = sendRaw(request, handler);
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw storageError(response.statusCode());
        }
        return response;
    }

    private ResponseStatusException storageError(int status) {
        return new ResponseStatusException(
            HttpStatus.BAD_GATEWAY,
            "Private photo storage returned HTTP " + status + "."
        );
    }

    private <T> HttpResponse<T> sendRaw(HttpRequest request, HttpResponse.BodyHandler<T> handler) {
        try {
            return httpClient.send(request, handler);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Photo storage request was interrupted.");
        } catch (IOException exception) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Photo storage request failed.");
        }
    }
}
