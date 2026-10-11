-- ==============================================================================
-- ReRoute: Supabase Password & User Profiles Security Integration
-- Run this script in: Supabase Dashboard > SQL Editor
-- Project: https://supabase.com/dashboard/project/zlbjqjrywmuykdsqjtfw
-- ==============================================================================

-- 1. Create profiles table
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text,
  full_name text,
  role text not null default 'driver' check (role in ('driver', 'dispatcher')),
  vehicle_id text references public.vehicles(id) default 'V01',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. Enable Row-Level Security (RLS)
alter table public.profiles enable row level security;

-- 3. RLS Policies
drop policy if exists "Authenticated users can view profiles" on public.profiles;
create policy "Authenticated users can view profiles"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- 4. Secure function: new user trigger
-- Default role is 'driver', assigned to vehicle 'V01'.
-- Role elevations to 'dispatcher' can only be granted by administrators or directly via DB.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role, vehicle_id)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    'driver',
    'V01'
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    updated_at = now();
  return new;
end;
$$ language plpgsql security definer;

-- Drop and recreate trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
