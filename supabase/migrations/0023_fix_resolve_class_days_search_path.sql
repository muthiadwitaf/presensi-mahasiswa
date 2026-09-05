-- app.resolve_class_days (0008_schedules_sessions.sql) referensi
-- meeting_sessions/schedules TANPA schema-qualify dan TANPA `set
-- search_path` sendiri - jadi ia memakai search_path yang aktif dari
-- pemanggilnya. Fungsi di 0021 memakai `search_path=''` (mengikuti
-- konvensi keamanan fungsi lain di codebase ini), yang membuat
-- resolve_class_days gagal dengan "relation meeting_sessions does not
-- exist" saat dipanggil dari dalamnya. Diverifikasi langsung lewat
-- percobaan ke /rest/v1/rpc/my_sessions_on.
--
-- Fix: pakai search_path='public' di fungsi-fungsi ini (bodinya sendiri
-- tetap fully-qualified dengan public., jadi tidak mengurangi keamanan),
-- supaya resolve_class_days yang dipanggil di dalamnya tetap bisa
-- resolve tabelnya secara normal.

create or replace function app.my_sessions_between(p_from date, p_to date)
returns table(
  session_date date, session_source text, meeting_session_id uuid, course_class_id uuid,
  course_code text, course_name text, lecturer_name text, start_time time, end_time time,
  mode delivery_mode, location_name text, meeting_url text, session_status session_status,
  attendance_id uuid, attendance_status attendance_status, check_in_at timestamptz, check_out_at timestamptz
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
    ar.id, ar.status, ar.check_in_at, ar.check_out_at
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
  attendance_id uuid, attendance_status attendance_status, check_in_at timestamptz, check_out_at timestamptz
)
language sql stable security definer set search_path = 'public' as $$
  select * from app.my_sessions_between(p_date, p_date)
$$;

create or replace function app.my_taught_sessions_on(p_date date default current_date)
returns table(
  session_source text, meeting_session_id uuid, course_class_id uuid, course_code text,
  course_name text, start_time time, end_time time, mode delivery_mode, location_name text,
  meeting_url text, session_status session_status
)
language plpgsql stable security definer set search_path = 'public' as $$
declare v_lecturer_id uuid;
begin
  v_lecturer_id := app.current_lecturer_id();
  if v_lecturer_id is null then
    return;
  end if;
  return query
  select
    rc.source, rc.session_id, ccl.course_class_id, c.code, c.name,
    rc.start_time, rc.end_time, rc.mode, loc.name, rc.meeting_url, rc.status
  from public.course_class_lecturers ccl
  join public.course_classes cc on cc.id = ccl.course_class_id
  join public.courses c on c.id = cc.course_id
  cross join lateral app.resolve_class_days(ccl.course_class_id, p_date, p_date) rc
  left join public.locations loc on loc.id = rc.location_id
  where ccl.lecturer_id = v_lecturer_id
  order by rc.start_time;
end $$;
