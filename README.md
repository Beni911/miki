# Powerlifting Tracker

Offline-first Flutter workout tracker with optional Supabase cloud sync.

## Set up cloud sync

1. Create a Supabase project.
2. Open the project's SQL Editor and run [`supabase/schema.sql`](supabase/schema.sql).
   The tables use row-level security so authenticated users can access only
   their own data.
3. Install dependencies, connect an Android phone (or start an emulator), then
   run the app with your project URL and public anon/publishable key:

   ```powershell
   flutter pub get
   flutter devices
   flutter run -d DEVICE_ID --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
   ```

   For an Android release, build an installable APK or Play Store bundle:

   ```powershell
   flutter build apk --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
   flutter build appbundle --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
   ```

   iOS is supported too; building and signing an iOS app requires macOS and
   Xcode. Use the same `--dart-define` values for release builds. The anon /
   publishable key is intended for client apps and is protected by RLS; never
   put the Supabase `service_role` secret in the app.
4. On the phone, open **Profile > Data > Cloud account** and sign in or create
   an account. Use **Sync now** to upload and download data.

If email confirmation is enabled in Supabase Auth, confirm the registration
email before signing in. Without the two build-time values, the app continues
to work locally and the cloud account controls remain disabled.

## Sync behavior

SQLite remains the local source of truth, so logging workouts does not require
an internet connection. Changes are queued locally and sent on **Sync now**.
The first sync uploads existing local data when the cloud account has no data;
later syncs upload queued changes and merge the account's cloud snapshot.
When both devices changed the same item before syncing, the most recently
uploaded local change wins. This version syncs workouts, programs, exercises,
personal records, and bodyweight entries. Profile preferences stored on the
device are not synced.

Each device is linked to the first cloud account it syncs with. To use a
different account on that device, clear the app's local data first; this avoids
accidentally uploading one person's workouts to another account. Keep using
JSON backups as an additional recovery option.
