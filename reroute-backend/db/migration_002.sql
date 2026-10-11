-- Auth users for the ReRoute Flutter app (run in Supabase SQL Editor).
-- Named app_users so it does not clash with Supabase Auth's auth.users.

create table if not exists app_users (
  id bigserial primary key,
  email text not null unique,
  name text not null,
  password_hash text not null,
  role text not null check (role in ('DRIVER', 'DISPATCHER')),
  vehicle_id text references vehicles(id),
  created_at timestamptz not null default now()
);

create unique index if not exists app_users_email_lower on app_users (lower(email));
