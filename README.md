# Field Notes

Field Notes is an offline-first field-service application. The current architecture
is:

```text
Flutter UI
  → BLoC/Cubit and feature repositories
  → Drift/SQLite local data and durable sync outbox
  → Spring Boot REST API
  → Supabase Auth JWT validation and PostgreSQL
```

SQLite is the mobile app's local source of truth. Mutations should be persisted
locally with their outbox operation before synchronization. Dashboard counts read
the local database; sync health is separate.

## Project layout

- `mobile/` — Flutter application, Drift database, offline repositories, sync engine.
- `backend/` — Spring Boot REST API, Flyway SQL migration and PostgreSQL configuration.
- `TEST_REPORT.md` — executed verification and known blockers.
- `IMPLEMENTATION_PLAN.md` — delivery priorities and acceptance criteria.

## Local development

### Mobile

Install Flutter, then:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

On an Android emulator, the default API host is `http://10.0.2.2:8080`. Configure
Supabase for the app with Flutter compile-time defines; never commit credentials:

```powershell
flutter run --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key> `
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

The source has placeholder Supabase values for builds that omit the defines; those
placeholders are not usable for authentication.

### Backend

The backend production profile is configured for PostgreSQL and Flyway. Provide
environment variables in the process environment (never commit credentials):

- `SPRING_PROFILES_ACTIVE` (use `local` for the local H2 development profile).
- `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`,
  `SPRING_DATASOURCE_PASSWORD`, or the individual `SUPABASE_DB_*` settings.
- `SUPABASE_JWK_SET_URI` for Supabase JWT signing-key verification, or
  `SUPABASE_JWT_SECRET` where the project still issues HS256 tokens.
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and optionally
  `SUPABASE_STORAGE_BUCKET` for private photo storage. The service-role key is
  backend-only and must never be passed to Flutter. The backend creates the
  configured bucket as private if it does not exist and refuses an existing
  public bucket.

Run the backend:

```powershell
cd backend
.\mvnw.cmd test
.\mvnw.cmd package
.\mvnw.cmd spring-boot:run
```

Tests currently use H2 through `backend/src/test/resources/application.properties`.
A successful H2 test does not verify Supabase connectivity or production migrations.
The SQL migration is in `backend/src/main/resources/db/migration/`.
Copy `backend/.env.example` into a local, untracked environment file or configure
the variables in your process environment; do not commit real credentials.

## Current delivery status

Static analysis, the existing automated suites and Android debug APK compilation
have been run; see [TEST_REPORT.md](./TEST_REPORT.md) for exact results. This
repository has not been verified against a live Supabase database or a connected
Android emulator in the latest delivery run. The report documents outstanding
release blockers; do not treat code presence as proof of production behavior.
