# Field Notes delivery verification

Updated: 2026-10-14

This report separates source-code inspection and automated test evidence from live
environment verification. A feature is not considered live-verified merely because
its source code exists or a unit test passes.

## Requirement status

| Requirement | Status | Evidence |
|---|---|---|
| Flutter static analysis | 🟢 COMPLETE & VERIFIED | `flutter analyze` completed with no issues after the account-isolation changes. |
| Flutter automated tests | 🟢 COMPLETE & VERIFIED | `flutter test`: all 36 tests passed, including scoped CRUD/outbox and conflict-resolution coverage. |
| Backend tests | 🟢 COMPLETE & VERIFIED | `backend\\mvnw.cmd test`: 6 tests passed against the test H2 configuration, including version-0 sync creates and photo metadata/ownership behavior. |
| Backend package | 🟢 COMPLETE & VERIFIED | `backend\\mvnw.cmd package`: `BUILD SUCCESS`. |
| Android debug APK build | 🟢 COMPLETE & VERIFIED | `flutter build apk --debug` completed before the clean rebuild. The subsequent `flutter clean` removed that debug artifact. |
| Android release APK build | 🟡 BUILT; DEVELOPMENT SIGNING ONLY | `flutter build apk --release` succeeded and produced a 59.7 MB APK. The Android release variant is configured to use the debug signing key and the application ID is `com.example.field_notes_test`; this is not a production-distributable release. |
| Public APK handoff | 🟡 PREVIEW RELEASE AVAILABLE | APK is attached to the public prerelease at `https://github.com/SADMAN-222/field-notes/releases/tag/android-preview-2026-10-14`. The shared Google Drive folder was accessible only in signed-out view and requires an authenticated session to upload; it does not currently contain the APK. |
| Local-first customer/site/note CRUD | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | Repository tests cover in-memory create/update/delete, persistence and outbox enqueue; no emulator or restart/offline device run was possible. |
| Dashboard local counts | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | Account-scoped count-stream regression test passes in the 35-test Flutter suite; live UI checks are blocked by missing emulator. |
| Note status specification | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | UI/default/sync statuses changed to `PENDING`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`; Drift migration maps legacy `DRAFT` to `PENDING` and `SUBMITTED` to `IN_PROGRESS`. Analyzer and full mobile test suite pass; device upgrade-path test is unavailable. |
| Offline note search by title/description/site/customer | 🟢 COMPLETE & VERIFIED | DAO uses user-scoped Drift joins; regression test covers site/customer name search. `flutter test` passed. |
| Offline persistence and outbox recovery across process restart | 🟠 PARTIAL | File-backed Drift database and durable outbox exist; kill/restart/reconnect was not tested on a device. |
| Push/pull and duplicate prevention after reinstall | 🟠 PARTIAL | Sync engine and pull cursor exist; no destructive reinstall/recovery run or end-to-end idempotency test was performed. |
| Conflict handling | 🟡 COMPONENT VERIFIED; DEVICE UNVERIFIED | Backend rejects stale versions with structured HTTP 409 conflicts; the mobile outbox preserves conflicts and offers an explicit keep-local/rebase retry. Backend and sync-engine regression tests pass; no live server/device conflict flow was run. |
| Backend user-scoped CRUD authorization | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | Controllers/repositories query entities by authenticated user; no two-account adversarial integration test was run. |
| Local user isolation on entity/detail/outbox paths | 🟡 COMPONENT VERIFIED; DEVICE UNVERIFIED | Repository/DAO reads, writes and outbox access are scoped to the authenticated user ID. New two-account SQLite tests verify list/detail isolation, rejected cross-account update, and separate outbox counts. Shared-device login/logout was not exercised. |
| Supabase PostgreSQL connection and persisted rows | ⚫ BLOCKED | Production configuration is PostgreSQL-capable, but no runtime Supabase credentials are configured in this environment and no live database query was performed. |
| Supabase JWT validation against live keys | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | Resource-server configuration supports JWKS or JWT secret; no live token validation was performed. |
| Secure private photo storage on Supabase | 🟡 IMPLEMENTED; LIVE STORAGE UNVERIFIED | Backend storage adapter uses a backend-only service key, verifies/provisions a private bucket, and persists per-user media metadata. Controller-level upload/download and ownership tests use mocked storage; live Supabase Storage and adapter HTTP behavior were not verified. |
| Photo/location device flows | 🟠 PARTIAL | Source paths exist; picker/location success, denial, restart, upload, and retry were not exercised on a device. |
| Emulator install, login and real CRUD | ⚫ BLOCKED | `adb devices -l` returned no connected devices. The latest APK built but was not installed or launched. |
| Live two-user isolation test | ⚫ BLOCKED | Local SQLite tests cover two account IDs; authenticated account switching requires live credentials and an emulator, neither available. |

## Executed commands and results

| Command | Result |
|---|---|
| `flutter analyze` (from `mobile`) | PASS — no issues found. |
| `flutter test` (from `mobile`) | PASS — all 36 tests passed, including account-scoped CRUD/outbox and explicit conflict retry coverage. |
| `backend\\mvnw.cmd test` (from `backend`) | PASS — 6 tests, 0 failures/errors. Test datasource uses H2; this is not a Supabase integration test. |
| `backend\\mvnw.cmd package` (from `backend`) | PASS — `BUILD SUCCESS`. |
| `flutter build apk --debug` (from `mobile`, before the later clean rebuild) | PASS — APK generated; `flutter clean` subsequently removed it. |
| `flutter build apk --release` (from `mobile`) | PASS — 59.7 MB APK generated. Kotlin incremental compilation is disabled to avoid cross-volume cache failures, and Gradle heap is capped at 3 GB for this 8 GB host. The output is debug-signed and is not suitable as a production release. |
| GitHub prerelease upload | PASS — public preview asset attached to `android-preview-2026-10-14`; README links to the asset and release. |
| `adb devices -l` | BLOCKED — no Android device/emulator listed; manual UI verification could not be performed. |
| Live Supabase/PostgreSQL queries | BLOCKED — no datasource/JWT environment configuration was available. No secrets were read or printed. |

## Important verified code observations

- Backend production properties select the PostgreSQL driver and use Flyway with
  Hibernate schema validation. Test properties instead explicitly select H2 and
  disable Flyway. A successful test/package therefore does not prove a Supabase
  connection or production migration.
- The migration defines user ownership foreign keys for customers, sites and notes.
- Backend entity routes and sync controller derive ownership from the authenticated
  principal; related site/customer references are checked against that user during
  sync push.
- Sync push removes local outbox entries after an HTTP success. It retains failed
  entries. Stale versions are preflighted and returned as HTTP 409 before batch
  mutation; client conflicts remain in the outbox until explicit user resolution.
  These behaviors are covered by tests, but not proven against a live deployment.
- Client-assigned UUID entities created at version 0 are inserted as new JPA
  entities by letting `@Version` initialize on persist. An integration regression
  test covers customer, site and field-note creation plus identical replay.
- The app's local database survives ordinary app restarts, but is intentionally not
  a substitute for restoring data after uninstall. Restore depends on verified
  server push/pull and has not been tested here.
- Sign-out now clears the signed-in user's local rows, outbox entries and app-owned
  photo files only after the pending-change confirmation/sync flow. This cleanup
  path has not been exercised on a device.
- Entity/detail reads, writes and outbox queries are scoped by user ID. The new
  in-memory Drift regression test proves local account separation, but does not
  substitute for authenticated account-switch testing against Supabase.

## Delivery blockers

1. Configure a non-production Supabase project and verify authenticated PostgreSQL,
   JWT, private Storage, ownership, migrations, sync acknowledgement, and recovery.
2. Connect `emulator-5554` (or another Android device) and run online/offline CRUD,
   process restart, reconnect, conflict resolution, photo/location, logout and
   account-isolation workflows.
3. Configure an application-owned Android package ID and production signing key
   before treating the current release APK as a production release. The repository's
   current Android release build type uses the debug signing configuration.

## Final assessment

**NOT LIVE-VERIFIED** — automated analysis/tests/package builds pass, and component
conflict handling plus private-photo controller behavior are implemented. Live
Supabase/PostgreSQL/Storage and emulator execution remain unavailable, so no
production-ready claim is made. The Android release variant currently uses a
debug key and must not be distributed as a production-signed release.
