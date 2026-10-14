# Field Notes

**Offline-first field-service notes for Android.** Record customers, job sites,
and field notes on the device, then synchronize queued changes through the
Field Notes API to Supabase when the service is configured and reachable.

> **Download:** [Android preview APK](https://github.com/SADMAN-222/field-notes/releases/download/android-preview-2026-10-14/Field-Notes-Android-Preview.apk) · [All GitHub releases](https://github.com/SADMAN-222/field-notes/releases) · [Google Drive folder](https://drive.google.com/drive/folders/1vOJJR4gB4LtAQN7TH6ZSic-Zf2YfOIe_)
>
> **Preview build, not a production release.** The APK is debug-signed, uses the
> development application ID `com.example.field_notes_test`, and was built
> without this deployment's Supabase URL or anon key. It can be installed for
> an initial app review, but sign-in and server synchronization require a
> correctly configured deployment. Do not distribute it as the production app.

## What the application does

- Maintains Customers, Sites, and Field Notes in a local SQLite database.
- Queues local changes for synchronization rather than requiring a network
  request for every edit.
- Shows dashboard totals from local data and tracks sync state separately.
- Scopes local records and queued operations to the signed-in account.
- Preserves version conflicts for explicit resolution instead of silently
  overwriting the server copy.
- Supports field-note photos through authenticated backend endpoints and a
  private Supabase Storage bucket when storage is configured.

The Android app is built with Flutter, BLoC/Cubit, and Drift/SQLite. The API is
Spring Boot, with Supabase Auth JWT validation, PostgreSQL, and Flyway-managed
database migrations:

```text
Flutter screens → BLoC/Cubit and repositories → Drift/SQLite + sync outbox
  → Spring Boot REST API → Supabase Auth → PostgreSQL and private Storage
```

## Download and install

1. Download the [Android preview APK](https://github.com/SADMAN-222/field-notes/releases/download/android-preview-2026-10-14/Field-Notes-Android-Preview.apk).
2. On the Android device, open the downloaded APK and approve installation
   from that source if Android asks.
3. For installation over USB with Android platform tools:

   ```powershell
   adb install -r .\Field-Notes-Android-Preview.apk
   ```

The preview package is signed with the Android debug key. Android treats it as
a different application from any future production-signed package; uninstalling
the preview may remove its local app data. The current APK is attached to the
GitHub prerelease above. The linked Drive folder does not currently contain the
APK; adding files there requires an authenticated Google Drive session.

## Current verification and limitations

| Area | Verified here |
|---|---|
| Flutter static analysis | Passed with no issues |
| Flutter tests | 36 passed |
| Backend tests | 6 passed against H2 |
| Backend package | Built successfully |
| Android APKs | Debug and release variants built; the release variant is debug-signed |
| Live Android workflow | Not verified; no emulator/device was connected |
| Supabase Auth, PostgreSQL, Storage | Not live-verified; deployment credentials were unavailable |

Automated test success is not evidence of a live Supabase deployment. In
particular, configure the mobile Supabase URL and anon/publishable key at build
time, deploy the backend with its database/JWT settings, and configure the
backend-only Storage service key before expecting authenticated sign-in or
online sync. See [TEST_REPORT.md](./TEST_REPORT.md) for commands, test scope,
and remaining release limitations.

## Run from source

### Requirements

- Flutter SDK and Dart SDK compatible with `mobile/pubspec.yaml`
- JDK 17 for the Spring Boot backend
- Android Studio/Android SDK for Android builds
- A configured Supabase project for real authentication and remote sync

### Flutter app

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key> `
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` is the Android emulator's route to the development host. Use the
reachable HTTPS API URL for a physical device or deployed backend. Never put a
service-role key in Flutter or pass one through a mobile build define.

Build a locally installable APK:

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key> `
  --dart-define=API_BASE_URL=<reachable-api-base-url>
```

The checked-in Android release build configuration currently uses debug
signing and a sample application ID. Before producing an office/production
distribution, configure an organization-owned application ID and a protected
release signing key; keep signing files and passwords out of Git.

### Spring Boot API

The backend has a local H2 profile for development and a PostgreSQL/Flyway
configuration for deployment. Configure environment variables in the backend
process; example files contain placeholders only.

Relevant settings:

- `SPRING_PROFILES_ACTIVE` — `local` for development; configure the deployment
  profile for PostgreSQL.
- `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`,
  `SPRING_DATASOURCE_PASSWORD`, or the `SUPABASE_DB_*` connection settings.
- `SUPABASE_JWK_SET_URI` or `SUPABASE_JWT_SECRET` for JWT verification,
  according to the Supabase project's token signing setup.
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and optionally
  `SUPABASE_STORAGE_BUCKET` for backend-only private photo storage.

The service-role key has broad privileges. Store it only in the backend's
secret manager/environment, restrict access, and rotate it if exposed. The
backend expects the photo bucket to be private.

```powershell
cd backend
.\mvnw.cmd test
.\mvnw.cmd package
.\mvnw.cmd spring-boot:run
```

Tests use H2; they do not validate production PostgreSQL migrations, live JWT
verification, or a real Supabase Storage bucket. Database migrations are under
`backend/src/main/resources/db/migration/`.

## Repository map

- `mobile/` — Flutter Android app, Drift database, repositories, and sync engine.
- `backend/` — Spring Boot API, authentication, persistence, and media storage.
- `TEST_REPORT.md` — detailed executed checks and outstanding verification.
- `IMPLEMENTATION_PLAN.md` — remaining delivery work and acceptance criteria.

## Security and configuration

Do not commit `.env` files, database passwords, JWT secrets, Supabase service-role
keys, keystores, or signing passwords. The tracked `.env.example` files are
templates, not working credentials. If a secret has been committed or shared,
rotate it in the relevant service before deployment.
