-- ==============================================================================
-- ReRoute: Supabase Auth & User Profiles Integration
-- Run this script in: Supabase Dashboard > SQL Editor
-- Project: https://supabase.com/dashboard/project/zlbjqjrywmuykdsqjtfw
-- ==============================================================================

-- 1. Create public profiles table (extends auth.users)
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text,
  full_name text,
  role text not null check (role in ('driver', 'dispatcher')),
  vehicle_id text references public.vehicles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. Enable Row-Level Security (RLS)
alter table public.profiles enable row level security;

-- 3. RLS Policies
-- Authenticated users can view profiles
drop policy if exists "Authenticated users can view profiles" on public.profiles;
create policy "Authenticated users can view profiles"
  on public.profiles for select
  to authenticated
  using (true);

-- Users can insert their own profile
drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

-- Users can update their own profile
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- 4. Trigger to automatically populate public.profiles upon auth.users signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role, vehicle_id)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'driver'),
    new.raw_user_meta_data->>'vehicle_id'
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    role = coalesce(excluded.role, public.profiles.role),
    vehicle_id = coalesce(excluded.vehicle_id, public.profiles.vehicle_id),
    updated_at = now();
  return new;
end;
$$ language plpgsql security definer;

-- Drop existing trigger if already defined
drop trigger if exists on_auth_user_created on auth.users;

-- Create the trigger
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
