create table schedules (
  id              uuid primary key default gen_random_uuid(),
  course_class_id uuid not null references course_classes(id) on delete cascade,
  day_of_week     smallint not null references ref_days(day_of_week),
  start_time      time not null,
  end_time        time not null,
  mode            delivery_mode not null default 'OFFLINE',
  location_id     uuid references locations(id) on delete set null,
  meeting_url     text,
  lecturer_id     uuid references lecturers(id) on delete set null,
  effective_from  date not null default current_date,
  effective_until date,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint schedules_time_chk check (end_time > start_time),
  constraint schedules_mode_loc_chk check (
    (mode = 'ONLINE'  and meeting_url is not null)
    or (mode = 'OFFLINE' and location_id is not null)
    or (mode = 'HYBRID'  and location_id is not null and meeting_url is not null)
  )
);
create index schedules_course_class_idx on schedules(course_class_id);
create index schedules_day_idx          on schedules(day_of_week) where is_active;
create index schedules_location_idx     on schedules(location_id);

create table meeting_sessions (
  id                    uuid primary key default gen_random_uuid(),
  course_class_id       uuid not null references course_classes(id) on delete cascade,
  schedule_id           uuid references schedules(id) on delete set null,
  meeting_number        smallint,
  session_type          session_type not null default 'REGULAR',
  session_date          date not null,
  start_time            time not null,
  end_time              time not null,
  mode                  delivery_mode not null,
  location_id           uuid references locations(id) on delete set null,
  meeting_url           text,
  lecturer_id           uuid references lecturers(id) on delete set null,
  topic                 text,
  status                session_status not null default 'SCHEDULED',

  replaces_session_id   uuid references meeting_sessions(id) on delete set null,
  original_date         date,
  reschedule_reason     text,
  cancelled_at          timestamptz,
  cancelled_by          uuid references users(id),
  cancellation_reason   text,

  checkin_opens_at      timestamptz,
  checkin_closes_at     timestamptz,
  late_threshold_at     timestamptz,
  require_geofence      boolean,
  require_face          boolean not null default true,

  starts_at             timestamptz,
  ends_at               timestamptz,

  opened_at             timestamptz,
  opened_by             uuid references users(id),
  closed_at             timestamptz,
  closed_by             uuid references users(id),
  notes                 text,
  created_by            uuid references users(id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint ms_time_chk check (end_time > start_time),
  constraint ms_mode_chk check (
    (mode = 'ONLINE'  and meeting_url is not null)
    or (mode  = 'OFFLINE' and location_id is not null)
    or (mode  = 'HYBRID'  and location_id is not null and meeting_url is not null)
  ),
  constraint ms_cancel_chk check (
    status <> 'CANCELLED' or (cancelled_at is not null and cancellation_reason is not null)
  )
);
create index meeting_sessions_date_idx         on meeting_sessions(session_date);
create index meeting_sessions_course_class_idx on meeting_sessions(course_class_id);
create index meeting_sessions_cc_date_idx      on meeting_sessions(course_class_id, session_date);
create index meeting_sessions_status_idx       on meeting_sessions(status)
  where status in ('OPEN','ONGOING','SCHEDULED');
create index meeting_sessions_starts_at_idx    on meeting_sessions(starts_at);
create index meeting_sessions_location_idx     on meeting_sessions(location_id);
create unique index meeting_sessions_regular_unique_idx
  on meeting_sessions(course_class_id, session_date, start_time)
  where session_type = 'REGULAR' and status <> 'CANCELLED';

create or replace function app.meeting_sessions_set_instants() returns trigger
language plpgsql as $$
declare v_tz text;
begin
  select coalesce(value #>> '{}', 'Asia/Jakarta') into v_tz from app_settings where key = 'campus_timezone';
  new.starts_at := (new.session_date + new.start_time) at time zone coalesce(v_tz,'Asia/Jakarta');
  new.ends_at   := (new.session_date + new.end_time)   at time zone coalesce(v_tz,'Asia/Jakarta');
  return new;
end $$;
create trigger meeting_sessions_set_instants_trg
  before insert or update of session_date, start_time, end_time on meeting_sessions
  for each row execute function app.meeting_sessions_set_instants();

create or replace function app.resolve_class_days(
  p_course_class_id uuid, p_from date, p_to date
) returns table (
  source        text,
  session_id    uuid,
  schedule_id   uuid,
  the_date      date,
  start_time    time,
  end_time      time,
  mode          delivery_mode,
  location_id   uuid,
  meeting_url   text,
  status        session_status,
  session_type  session_type
) language sql stable as $$
  with sessions as (
    select 'SESSION'::text as source, ms.id as session_id, ms.schedule_id, ms.session_date as the_date,
           ms.start_time, ms.end_time, ms.mode, ms.location_id, ms.meeting_url, ms.status, ms.session_type
    from meeting_sessions ms
    where ms.course_class_id = p_course_class_id
      and ms.session_date between p_from and p_to
  ),
  expanded as (
    select 'SCHEDULE'::text as source, null::uuid as session_id, s.id as schedule_id, d::date as the_date,
           s.start_time, s.end_time, s.mode, s.location_id, s.meeting_url,
           'SCHEDULED'::session_status as status, 'REGULAR'::session_type as session_type
    from schedules s
    cross join generate_series(p_from, p_to, interval '1 day') d
    where s.course_class_id = p_course_class_id
      and s.is_active
      and extract(isodow from d) = s.day_of_week
      and d::date >= s.effective_from
      and (s.effective_until is null or d::date <= s.effective_until)
  )
  select * from sessions
  union all
  select e.* from expanded e
  where not exists (select 1 from sessions x where x.the_date = e.the_date);
$$;

create or replace function app.ensure_session_for(
  p_course_class_id uuid, p_date date
) returns uuid
language plpgsql as $$
declare v_id uuid; v_row record;
begin
  select id into v_id from meeting_sessions
  where course_class_id = p_course_class_id and session_date = p_date
    and session_type = 'REGULAR' and status <> 'CANCELLED';
  if v_id is not null then return v_id; end if;

  select * into v_row from schedules
  where course_class_id = p_course_class_id
    and is_active
    and extract(isodow from p_date) = day_of_week
    and p_date >= effective_from
    and (effective_until is null or p_date <= effective_until)
  limit 1;
  if v_row is null then return null; end if;

  insert into meeting_sessions (course_class_id, schedule_id, session_type, session_date,
    start_time, end_time, mode, location_id, meeting_url, lecturer_id, status)
  values (p_course_class_id, v_row.id, 'REGULAR', p_date,
    v_row.start_time, v_row.end_time, v_row.mode, v_row.location_id, v_row.meeting_url,
    v_row.lecturer_id, 'SCHEDULED')
  on conflict (course_class_id, session_date, start_time) where session_type = 'REGULAR' and status <> 'CANCELLED'
  do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from meeting_sessions
    where course_class_id = p_course_class_id and session_date = p_date
      and session_type = 'REGULAR' and status <> 'CANCELLED';
  end if;
  return v_id;
end $$;

create or replace function app.resolve_geofence(p_location_id uuid)
returns table(lat double precision, lng double precision, radius_m integer, enforced boolean, source text)
language plpgsql stable as $$
declare v_loc record; v_default_lat double precision; v_default_lng double precision; v_default_radius integer;
begin
  if p_location_id is not null then
    select * into v_loc from locations where id = p_location_id;
    if v_loc.is_geofenced = false then
      return query select v_loc.latitude, v_loc.longitude, v_loc.radius_meters, false, 'SKIPPED';
      return;
    end if;
    while v_loc.id is not null loop
      if v_loc.latitude is not null and v_loc.radius_meters is not null then
        return query select v_loc.latitude, v_loc.longitude, v_loc.radius_meters, true, v_loc.kind::text;
        return;
      end if;
      exit when v_loc.parent_id is null;
      select * into v_loc from locations where id = v_loc.parent_id;
    end loop;
  end if;
  select (value #>> '{}')::double precision into v_default_lat from app_settings where key='campus_latitude';
  select (value #>> '{}')::double precision into v_default_lng from app_settings where key='campus_longitude';
  select (value #>> '{}')::integer into v_default_radius from app_settings where key='geofence_radius_meters';
  return query select v_default_lat, v_default_lng, v_default_radius, true, 'SETTINGS';
end $$;
