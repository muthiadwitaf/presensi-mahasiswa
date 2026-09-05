-- Room catalogue + geofence tree (ROOM -> BUILDING -> CAMPUS). Replaces `ruang`.
create table locations (
  id            uuid primary key default gen_random_uuid(),
  parent_id     uuid references locations(id) on delete set null,
  kind          location_kind not null default 'ROOM',
  code          text not null unique,
  name          text not null,
  building      text,
  floor         text,
  capacity      smallint,
  latitude      double precision check (latitude  between -90  and 90),
  longitude     double precision check (longitude between -180 and 180),
  radius_meters integer check (radius_meters between 10 and 5000),
  altitude_m    real,
  is_geofenced  boolean not null default true,
  is_active     boolean not null default true,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint locations_geo_complete_chk check (
    (latitude is null and longitude is null)
    or (latitude is not null and longitude is not null)
  )
);
create index locations_parent_idx on locations(parent_id);
create index locations_kind_idx   on locations(kind) where is_active;

-- Plain haversine distance in metres; PostGIS is unnecessary at campus scale.
create or replace function app.haversine_meters(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) returns double precision
language sql immutable as $$
  select 6371000 * 2 * asin(sqrt(
    sin(radians(lat2-lat1)/2)^2 +
    cos(radians(lat1)) * cos(radians(lat2)) * sin(radians(lng2-lng1)/2)^2
  ))
$$;
