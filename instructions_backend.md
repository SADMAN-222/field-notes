Please implement the Spring Boot backend for the Field Notes application in the ackend/ directory.

Project Requirements:
1. Tech Stack: Java 21, Spring Boot, PostgreSQL, Spring Data JPA, Spring Security, Flyway.
2. Entities:
   - User (id, email, password_hash)
   - Customer (id UUID, user_id, name, contact_information, created_at, updated_at, deleted_at, version)
   - Site (id UUID, user_id, customer_id, site_name, address, created_at, updated_at, deleted_at, version)
   - FieldNote (id UUID, user_id, site_id, title, description, status, photo_path, lat, lng, recorded_at, created_at, updated_at, deleted_at, version)
   - SyncChange (for the pull API change log)
   - RefreshToken
3. Authentication: JWT with access/refresh tokens. Endpoints: /api/v1/auth/register, login, refresh, logout.
4. CRUD APIs: Provide standard REST endpoints for customers, sites, notes. Ensure cross-user isolation.
5. Synchronization:
   - POST /api/v1/sync/push: batched updates. Handle idempotency, expected versions (conflicts).
   - GET /api/v1/sync/pull?cursor=...: durable change log, pagination.
6. Flyway: Create ackend/src/main/resources/db/migration/V1__Init.sql with the initial schema.
7. Media: /api/v1/notes/{id}/photo. Save files locally to a configured directory.
8. Tests: Add some basic backend tests.

Check out the MASTER PROMPT in the parent context if you need more details. Start immediately by writing the required Java files, configs, and Flyway migration.
