<div align="center">

# Field Notes

### Capture the work. Keep moving.

An offline-first Android app for field teams to manage customers, job sites, and
field notes, then synchronize changes through a Spring Boot API when online.

[![Android preview](https://img.shields.io/badge/Android-preview-168C83?logo=android&logoColor=white)](https://github.com/SADMAN-222/field-notes/releases/tag/android-preview-2026-10-14)
[![APK downloads](https://img.shields.io/github/downloads/SADMAN-222/field-notes/android-preview-2026-10-14/Field-Notes-Android-Preview.apk?label=APK%20downloads)](https://github.com/SADMAN-222/field-notes/releases/tag/android-preview-2026-10-14)
[![Flutter](https://img.shields.io/badge/mobile-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Backend](https://img.shields.io/badge/API-Spring%20Boot-6DB33F?logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot)
[![Database](https://img.shields.io/badge/database-Supabase-3FCF8E?logo=supabase&logoColor=white)](https://supabase.com/)

[Download Android preview](https://github.com/SADMAN-222/field-notes/releases/download/android-preview-2026-10-14/Field-Notes-Android-Preview.apk) ·
[Release details](https://github.com/SADMAN-222/field-notes/releases/tag/android-preview-2026-10-14) ·
[Google Drive folder](https://drive.google.com/drive/folders/1vOJJR4gB4LtAQN7TH6ZSic-Zf2YfOIe_)

</div>

> [!IMPORTANT]
> **This is an evaluation preview, not a production release.** The APK is
> debug-signed, uses the sample Android ID `com.example.field_notes_test`, and
> does not include deployment-specific Supabase settings. Install it to review
> the app shell and locally available behavior; working sign-in and remote sync
> require a configured deployment. The linked Drive folder is provided for
> reference; the current APK is hosted on GitHub Releases.

## What is Field Notes?

Field Notes is designed for field work where connectivity may be unreliable.
Customers, sites, and notes are stored in the device's local SQLite database,
with changes queued for synchronization instead of requiring a successful
network request for each edit.

### Core capabilities

- Create and manage customers, sites, and field notes.
- Keep local records available offline using Drift and SQLite.
- Queue account-scoped changes in a durable outbox for synchronization.
- View dashboard totals from local data, separately from sync health.
- Detect version conflicts and keep local changes available for explicit
  resolution.
- Attach field-note photos through authenticated API routes backed by a private
  Supabase Storage bucket when configured.

## Download for Android

<div align="center">

### [Download the Field Notes Android preview APK](https://github.com/SADMAN-222/field-notes/releases/download/android-preview-2026-10-14/Field-Notes-Android-Preview.apk)

**[Open the release page](https://github.com/SADMAN-222/field-notes/releases/tag/android-preview-2026-10-14)** · **[Browse all releases](https://github.com/SADMAN-222/field-notes/releases)**

</div>

1. Download the APK using the link above on your Android device.
2. Open the downloaded file. If Android prompts you, allow installation from
   that source and continue installing.
3. Alternatively, install it from a computer with Android platform tools:

   ```powershell
   adb install -r .\Field-Notes-Android-Preview.apk
   ```

The APK is approximately 60 MB. Android considers a debug-signed preview a
different app from a future organization-signed release. Uninstalling the
preview can erase its local app data.

## Project status

| Check | Result |
|---|---|
| Flutter static analysis | Passed; no issues reported |
| Flutter automated tests | 36 passed |
| Backend automated tests | 6 passed against H2 |
| Backend package build | Passed |
| Android APK build | Passed; preview APK is debug-signed |
| Live emulator workflow | Not verified; no emulator/device was connected |
| Live Supabase Auth, PostgreSQL, and Storage | Not verified; deployment configuration was unavailable |

Automated checks do not prove that a live backend or Supabase project is
working. The preview build has no deployment-specific Supabase URL or public
key, so do not expect sign-in or online synchronization to work until a
deployment is configured. The server also needs valid database/JWT settings
and a backend-only Storage service key for photo synchronization.

See [TEST_REPORT.md](./TEST_REPORT.md) for detailed test commands, evidence,
and limitations. See [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) for
remaining delivery work.

## How it works

```text
Flutter UI
    ↓
BLoC/Cubit and feature repositories
    ↓
Drift / SQLite  +  durable sync outbox
    ↓
Spring Boot REST API
    ↓
Supabase Auth JWT → PostgreSQL and private Storage
```

The mobile database is the local source of truth for field records and
dashboard counts. Synchronization is handled by the existing sync engine; the
app does not require a second network-based CRUD path for local work.

## Run from source

### Requirements

- Flutter and Dart versions compatible with [`mobile/pubspec.yaml`](mobile/pubspec.yaml)
- JDK 17 for the backend
- Android Studio and Android SDK for Android builds
- A Supabase project and configured backend for authenticated sign-in and
  remote synchronization

### Run the Flutter app

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

`10.0.2.2` is the Android emulator's route to the development computer. For a
physical device, use an API host reachable from that device. Never put a
Supabase service-role key in the Flutter app or pass it as a mobile build
define.

### Build an Android APK

```powershell
cd mobile
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key> `
  --dart-define=API_BASE_URL=<reachable-api-base-url>
```

The current Android configuration still uses the sample application ID and
debug signing for the release variant. Before an office-wide or public
production distribution, set an organization-owned application ID and
configure protected release signing credentials.

### Run the Spring Boot backend

Configure these values in the backend environment. The tracked `.env.example`
files contain placeholders, not usable credentials.

- `SPRING_PROFILES_ACTIVE` — `local` for local development, or the deployment
  profile for PostgreSQL.
- `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, and
  `SPRING_DATASOURCE_PASSWORD`, or the corresponding `SUPABASE_DB_*` values.
- `SUPABASE_JWK_SET_URI` or `SUPABASE_JWT_SECRET`, according to the Supabase
  project's JWT signing configuration.
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and optionally
  `SUPABASE_STORAGE_BUCKET` for private photo storage.

The Supabase service-role key has broad access. Keep it only in the backend's
secret store/environment; never commit it or include it in a mobile build.
Configure the photo bucket as private.

```powershell
cd backend
.\mvnw.cmd test
.\mvnw.cmd package
.\mvnw.cmd spring-boot:run
```

Backend tests use H2. They do not validate production PostgreSQL migrations,
live JWT verification, or a real Supabase Storage bucket. Database migrations
are in [`backend/src/main/resources/db/migration/`](backend/src/main/resources/db/migration/).

## Repository structure

| Path | Purpose |
|---|---|
| [`mobile/`](mobile/) | Flutter Android application, Drift database, repositories, and sync engine |
| [`backend/`](backend/) | Spring Boot API, authentication, database access, and private media integration |
| [`TEST_REPORT.md`](TEST_REPORT.md) | Executed checks, verification evidence, and blockers |
| [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) | Remaining work and acceptance criteria |

## Security

Do not commit `.env` files, database passwords, JWT secrets, Supabase
service-role keys, Android keystores, or signing passwords. If a credential is
ever exposed, rotate it with the service that issued it before deployment.
