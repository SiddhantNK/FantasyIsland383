-- ReRoute: run once in Supabase Dashboard > SQL Editor

create table vehicles (
  id text primary key,
  weight_cap_kg numeric not null,
  volume_cap_m3 numeric not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','FAILED')),
  failed_at time,
  failed_location text
);

create table locations (
  id text primary key,
  name text not null,
  type text not null default 'CUSTOMER' check (type in ('DEPOT','CUSTOMER','JUNCTION')),
  lat numeric,
  lng numeric
);

-- Editable travel-time matrix (minutes). Closures are derived from confirmed
-- ROAD_CLOSURE disruptions by the backend; this table is never overwritten.
create table travel_times (
  from_id text references locations(id),
  to_id text references locations(id),
  minutes numeric not null check (minutes >= 0),
  primary key (from_id, to_id)
);

create table orders (
  id text primary key,
  location_id text not null references locations(id),
  weight_kg numeric not null,
  volume_m3 numeric not null,
  earliest time not null,
  latest time not null,
  service_min int not null default 10,
  priority int not null default 1,
  status text not null default 'PENDING'
    check (status in ('PENDING','ASSIGNED','COMPLETED','UNASSIGNED'))
);

create table disruptions (
  id bigserial primary key,
  source text not null check (source in ('FORM','AI_PARSER')),
  raw_text text,
  event_type text not null
    check (event_type in ('VEHICLE_FAILURE','ROAD_CLOSURE','URGENT_ORDER')),
  vehicle_id text references vehicles(id),
  location_id text references locations(id),
  from_location text references locations(id),
  to_location text references locations(id),
  incident_time time,
  end_time time,
  details jsonb,                         -- urgent order payload, notes
  validation_errors jsonb not null default '[]',
  status text not null default 'PENDING'
    check (status in ('PENDING','CONFIRMED','REJECTED')),
  created_at timestamptz not null default now()
);

-- Original plan = version 1 with parent_plan_id null. Revisions: version +1, parent set.
create table route_plans (
  id bigserial primary key,
  version int not null,
  parent_plan_id bigint references route_plans(id),
  disruption_id bigint references disruptions(id),
  feasible boolean not null default true,
  created_at timestamptz not null default now()
);

-- Unassigned/Broken orders: vehicle_id null, status 'BROKEN', reason filled.
create table route_stops (
  id bigserial primary key,
  plan_id bigint not null references route_plans(id) on delete cascade,
  vehicle_id text references vehicles(id),
  order_id text references orders(id),
  seq int,
  arrival time,
  wait_min int default 0,
  departure time,
  status text not null default 'PLANNED'
    check (status in ('PLANNED','COMPLETED','KEPT','MOVED','BROKEN')),
  reason text,
  constraint stop_needs_vehicle check (vehicle_id is not null or status = 'BROKEN')
);

create table replanning_history (
  id bigserial primary key,
  old_plan_id bigint references route_plans(id),
  new_plan_id bigint references route_plans(id),
  disruption_id bigint references disruptions(id),
  summary text,
  created_at timestamptz not null default now()
);

create index on route_stops (plan_id, vehicle_id, seq);
create index on disruptions (status);

-- Seed data: 3 vehicles, depot + 10 customers, 10 orders
insert into vehicles (id, weight_cap_kg, volume_cap_m3) values
  ('V01', 1000, 8), ('V02', 800, 6), ('V03', 1200, 10);

insert into locations (id, name, type) values
  ('DEPOT', 'Main Depot', 'DEPOT'),
  ('C01','Customer 01','CUSTOMER'), ('C02','Customer 02','CUSTOMER'),
  ('C03','Customer 03','CUSTOMER'), ('C04','Customer 04','CUSTOMER'),
  ('C05','Customer 05','CUSTOMER'), ('C06','Customer 06','CUSTOMER'),
  ('C07','Customer 07','CUSTOMER'), ('C08','Customer 08','CUSTOMER'),
  ('C09','Customer 09','CUSTOMER'), ('C10','Customer 10','CUSTOMER');

insert into orders (id, location_id, weight_kg, volume_m3, earliest, latest, service_min, priority) values
  ('O01','C01',200,1.5,'09:00','12:00',10,1), ('O02','C02',350,2.0,'09:00','13:00',10,1),
  ('O03','C03',150,1.0,'10:00','14:00',10,2), ('O04','C04',400,3.0,'09:30','12:30',15,1),
  ('O05','C05',250,2.0,'10:00','15:00',10,1), ('O06','C06',300,2.5,'09:00','13:00',10,2),
  ('O07','C07',180,1.2,'11:00','16:00',10,1), ('O08','C08',500,4.0,'09:00','14:00',15,1),
  ('O09','C09',220,1.8,'10:30','15:30',10,1), ('O10','C10',270,2.2,'09:30','13:30',10,3);

-- Placeholder symmetric travel-time matrix; edit values in the table editor as needed
insert into travel_times (from_id, to_id, minutes)
select a.id, b.id, case when a.id = b.id then 0 else 8 + abs(a.n - b.n) * 3 end
from (select id, row_number() over (order by id <> 'DEPOT', id) n from locations) a
cross join (select id, row_number() over (order by id <> 'DEPOT', id) n from locations) b;