-- Tambah minutes_late + koordinat check-in ke my_sessions_on/between,
-- dipakai kartu "Absensi Hari Ini" untuk banner "Tepat waktu/Terlambat X
-- menit" dan baris lokasi - sebelumnya cuma status+jam.
--
-- Postgres tidak izinkan CREATE OR REPLACE mengubah return type (OUT
-- params) fungsi yang sudah ada - drop dulu semua yang tipe returnnya
-- berubah, dalam urutan aman (wrapper public.* dulu, baru app.*).
drop function if exists public.my_sessions_on(date);
drop function if exists public.my_sessions_between(date, date);
drop function if exists app.my_sessions_on(date);
drop function if exists app.my_sessions_between(date, date);

create or replace function app.my_sessions_between(p_from date, p_to date)
returns table(
  session_date date, session_source text, meeting_session_id uuid, course_class_id uuid,
  course_code text, course_name text, lecturer_name text, start_time time, end_time time,
  mode delivery_mode, location_name text, meeting_url text, session_status session_status,
  attendance_id uuid, attendance_status attendance_status, check_in_at timestamptz, check_out_at timestamptz,
  minutes_late integer, check_in_latitude double precision, check_in_longitude double precision
)
language plpgsql stable security definer set search_path = 'public' as $$
declare v_student_id uuid;
begin
  v_student_id := app.current_student_id();
  if v_student_id is null then
    return;
  end if;
  return query
  select
    rc.the_date, rc.source, rc.session_id, e.course_class_id, c.code, c.name, l.full_name,
    rc.start_time, rc.end_time, rc.mode, loc.name, rc.meeting_url, rc.status,
    ar.id, ar.status, ar.check_in_at, ar.check_out_at,
    ar.minutes_late, ar.latitude, ar.longitude
  from public.enrollments e
  join public.course_classes cc on cc.id = e.course_class_id
  join public.courses c on c.id = cc.course_id
  left join public.lecturers l on l.id = cc.primary_lecturer_id
  cross join lateral app.resolve_class_days(e.course_class_id, p_from, p_to) rc
  left join public.locations loc on loc.id = rc.location_id
  left join public.attendance_records ar
    on ar.student_id = v_student_id and ar.meeting_session_id = rc.session_id
  where e.status = 'ACTIVE'
  order by rc.the_date, rc.start_time;
end $$;

create or replace function app.my_sessions_on(p_date date default current_date)
returns table(
  session_date date, session_source text, meeting_session_id uuid, course_class_id uuid,
  course_code text, course_name text, lecturer_name text, start_time time, end_time time,
  mode delivery_mode, location_name text, meeting_url text, session_status session_status,
  attendance_id uuid, attendance_status attendance_status, check_in_at timestamptz, check_out_at timestamptz,
  minutes_late integer, check_in_latitude double precision, check_in_longitude double precision
)
language sql stable security definer set search_path = 'public' as $$
  select * from app.my_sessions_between(p_date, p_date)
$$;

create or replace function public.my_sessions_on(p_date date default current_date)
returns table(
  session_date date, session_source text, meeting_session_id uuid, course_class_id uuid,
  course_code text, course_name text, lecturer_name text, start_time time, end_time time,
  mode delivery_mode, location_name text, meeting_url text, session_status session_status,
  attendance_id uuid, attendance_status attendance_status, check_in_at timestamptz, check_out_at timestamptz,
  minutes_late integer, check_in_latitude double precision, check_in_longitude double precision
)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_sessions_on(p_date)
$$;

create or replace function public.my_sessions_between(p_from date, p_to date)
returns table(
  session_date date, session_source text, meeting_session_id uuid, course_class_id uuid,
  course_code text, course_name text, lecturer_name text, start_time time, end_time time,
  mode delivery_mode, location_name text, meeting_url text, session_status session_status,
  attendance_id uuid, attendance_status attendance_status, check_in_at timestamptz, check_out_at timestamptz,
  minutes_late integer, check_in_latitude double precision, check_in_longitude double precision
)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_sessions_between(p_from, p_to)
$$;
