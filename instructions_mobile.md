Please implement the Flutter mobile application for the Field Notes application in the mobile/ directory.

Project Requirements:
1. Tech Stack: Flutter, BLoC, Drift (SQLite), Dio, Flutter Secure Storage, SharedPreferences.
2. Local Database (Drift):
   - Tables: Customers, Sites, FieldNotes, SyncOutbox (for pending changes), SyncMetadata.
   - UI should be driven by streams from Drift.
3. Sync Engine:
   - Outbox pattern: Every local mutation (Create/Update/Delete) saves the record AND an outbox entry in the same transaction.
   - Push: read outbox, send to backend, handle conflicts, mark done.
   - Pull: read from backend via cursor, apply changes to local DB, update cursor.
4. Features:
   - Auth UI (Login/Register).
   - Dashboard (stats).
   - Customers list and create/edit form.
   - Sites list and create/edit form.
   - Field Notes list (search by title/description, filter by status/site) and create/edit form.
   - Settings: Default Note Status (saved in SharedPreferences).
5. Photos & Location: Integrate image_picker and geolocator. Upload photos separately from metadata.
6. Offline-first: The app must work fully offline after login.

Check out the MASTER PROMPT in the parent context if you need more details. Start immediately by writing the required Dart files, Drift tables, and BLoC components.
