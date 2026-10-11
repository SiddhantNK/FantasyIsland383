# ReRoute Flutter app

## Configure Supabase email/password authentication

1. Create or open the team's project at [supabase.com](https://supabase.com).
2. In **Project Settings → API**, copy the **Project URL** and the **publishable/anon key**. The Flutter app must only use this public key; never put the `service_role` key in the app.
3. In **Authentication → Providers → Email**, enable the Email provider. Choose whether **Confirm email** is required. For a real deployment, leave confirmation enabled and configure SMTP under **Authentication → SMTP Settings** (the default service is rate-limited).
4. In **Authentication → URL Configuration**, configure the app's allowed redirect URLs if you later add deep-link password recovery. The current flow sends a reset email; configure the redirect target before relying on recovery links in production.
5. Fetch Flutter packages from this directory:

   ```sh
   flutter pub get
   ```

6. Run the app with the project values supplied at build/run time:

   ```sh
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
   ```

   On PowerShell, use one line or replace `\` with PowerShell's backtick continuation. These values are public client configuration, not passwords or service credentials. Do not use the Supabase `service_role` key here.

7. In the app, create an account with email/password and select Driver or Dispatcher. If email confirmation is enabled, confirm the email using the link Supabase sends, then sign in. Existing accounts can sign in, and **Forgot password?** sends a reset email.

## Important security note

The app stores the chosen role and driver vehicle in Supabase user metadata for UI behavior. This is not an authorization boundary: users can edit their own metadata. The current FastAPI endpoints also do not validate Supabase access tokens and remain accessible without signing in. Before production, enforce authorization on the backend (verify each bearer token and authorize roles) and apply least-privilege policies to any Supabase tables exposed to clients. The app itself uses the anon/publishable key only and does not access the database directly.
