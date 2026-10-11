-- Run once in Supabase SQL Editor (after the original schema).

-- 1. unassigned / broken orders are stored as stops with no vehicle
alter table route_stops alter column vehicle_id drop not null;

-- 2. the simulated travel-time matrix (minutes, directed)
create table if not exists travel_times (
  from_id text not null references locations(id),
  to_id   text not null references locations(id),
  minutes int  not null check (minutes >= 0),
  primary key (from_id, to_id)
);
