# Field Notes delivery plan

Updated: 2026-10-14

Do not replace the existing Flutter → BLoC/repository → Drift/outbox → Spring Boot
→ Supabase architecture. Prioritize verified data safety over cosmetic work.

## P0 — release blockers

| Work | Status | Acceptance evidence |
|---|---|---|
| Preserve local customer/site/note create, update and delete with atomic outbox writes | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | Existing in-memory repository tests pass; device offline/restart run still required. |
| Scope every local entity read/update/delete and outbox operation to the authenticated user, including detail-by-ID and related entities | 🟡 COMPONENT VERIFIED; DEVICE UNVERIFIED | User-scoped repository/DAO APIs and outbox filtering are in place. Two-account Drift tests cover list/detail isolation, mutation rejection and outbox separation; live account switching still needs an emulator and test identities. |
| Verify authenticated push/pull against the configured Supabase PostgreSQL database | ⚫ NOT IMPLEMENTED | No live Supabase configuration/query was available in this environment. |
| Verify server ownership, foreign keys, relationships, timestamps and sync acknowledgement | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | Backend derives user identity and checks relationships; add authenticated PostgreSQL integration tests and inspect persisted rows. |
| Define a deterministic conflict policy and expose a recoverable conflict state | 🟡 COMPONENT VERIFIED; DEVICE UNVERIFIED | Backend preflights versions and returns structured 409 conflicts; the client preserves outbox rows until explicit keep-local/rebase. Backend and sync-engine tests pass; live device/server flow is unrun. |
| Verify retry, idempotency, duplicate prevention, reinstall recovery and dashboard counts | 🟠 PARTIAL | Replayed sync creates and account-scoped local counts are component-tested; full online/offline/reinstall sequence remains unrun. |

## P1 — important behavior

| Work | Status | Acceptance evidence |
|---|---|---|
| Keep note states aligned to `PENDING`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED` | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | Updated UI/preferences/sync defaults and a versioned local migration; automated suite passes, but exercise the existing-database upgrade path on a device. |
| Search notes offline by title, description, site and customer | 🟢 COMPLETE & VERIFIED | Drift query now joins user-scoped site/customer rows; added regression assertions and `flutter test` passes. |
| Verify search/filter combinations, empty results, and clear behavior | 🟠 PARTIAL | Source-level filters exist; full device test still required. |
| Secure and persist private photo synchronization | 🟡 IMPLEMENTED; LIVE STORAGE UNVERIFIED | Backend proxies uploads/downloads through a private Supabase Storage bucket and records ownership metadata. Controller tests mock Storage; real project configuration and live upload/download are still required. |
| Verify location permission denial, permanent denial, unavailable GPS and offline save | 🟠 PARTIAL | Service has fallback handling in source; device verification not performed. |

## P2 — delivery quality

| Work | Status | Acceptance evidence |
|---|---|---|
| Verify all important loading, empty and error states | 🟠 PARTIAL | Automated/widget coverage is limited; screen-by-screen runtime checks needed. |
| Verify settings/logout warning and sync recovery | 🟡 IMPLEMENTED BUT NOT FULLY VERIFIED | Relevant UI and outbox checks exist; device test needed. |
| Maintain accurate test and user documentation | 🟢 COMPLETE & VERIFIED | Root README and this plan describe architecture, setup and unverified blockers. |
| Add PostgreSQL-backed integration tests | ⚫ NOT IMPLEMENTED | Current backend tests use H2; provision a safe test database and test JWT identity/ownership. |

## P3 — deferred

- Cosmetic-only refinements. Do not spend release time here while P0 blockers remain.

## Execution order

1. Configure a non-production Supabase test project and validate database ownership,
   relationships, push/pull, retry, private Storage and idempotency.
2. Run the prescribed full workflow on an emulator, including airplane mode, process
   restart, reconnect, logout/login, and reinstall/recovery.
3. Configure the production Android application ID and signing credentials before
   distribution; do not use the current debug-signing release variant in production.
4. Update `TEST_REPORT.md` only with commands and workflows actually executed.
