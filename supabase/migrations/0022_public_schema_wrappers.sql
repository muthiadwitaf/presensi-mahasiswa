-- PostgREST hanya resolve fungsi tanpa qualifier schema terhadap schema
-- default (public), kecuali request mengirim header Accept-Profile/
-- Content-Profile untuk memilih schema lain dari daftar "Exposed schemas".
-- supabase-js client default (termasuk semua Edge Function di sini, lihat
-- _shared/clients.ts) TIDAK mengirim header itu - jadi RPC ke fungsi di
-- schema `app` gagal dengan PGRST202 walau `app` sudah ditambahkan ke
-- Exposed schemas. Diverifikasi langsung lewat percobaan ke
-- /rest/v1/rpc/my_sessions_on.
--
-- Fix untuk RPC baru sesi ini: wrapper tipis di schema public yang
-- meneruskan ke fungsi app.* aslinya (logic tetap satu tempat, tidak
-- diduplikasi). CATATAN: bug yang sama kemungkinan besar berlaku juga untuk
-- ensure_session_for/resolve_geofence/commit_attendance/
-- log_failed_verification yang dipanggil submit-attendance dkk - itu di
-- luar scope migration ini, perlu wrapper serupa sebelum submit-attendance
-- benar-benar dicoba end-to-end.

create or replace function public.my_sessions_on(p_date date default current_date)
returns table(
  session_date date, session_source text, meeting_session_id uuid, course_class_id uuid,
  course_code text, course_name text, lecturer_name text, start_time time, end_time time,
  mode delivery_mode, location_name text, meeting_url text, session_status session_status,
  attendance_id uuid, attendance_status attendance_status, check_in_at timestamptz, check_out_at timestamptz
)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_sessions_on(p_date)
$$;
revoke execute on function public.my_sessions_on(date) from public, anon;
grant execute on function public.my_sessions_on(date) to authenticated;

create or replace function public.my_sessions_between(p_from date, p_to date)
returns table(
  session_date date, session_source text, meeting_session_id uuid, course_class_id uuid,
  course_code text, course_name text, lecturer_name text, start_time time, end_time time,
  mode delivery_mode, location_name text, meeting_url text, session_status session_status,
  attendance_id uuid, attendance_status attendance_status, check_in_at timestamptz, check_out_at timestamptz
)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_sessions_between(p_from, p_to)
$$;
revoke execute on function public.my_sessions_between(date, date) from public, anon;
grant execute on function public.my_sessions_between(date, date) to authenticated;

create or replace function public.my_taught_sessions_on(p_date date default current_date)
returns table(
  session_source text, meeting_session_id uuid, course_class_id uuid, course_code text,
  course_name text, start_time time, end_time time, mode delivery_mode, location_name text,
  meeting_url text, session_status session_status
)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_taught_sessions_on(p_date)
$$;
revoke execute on function public.my_taught_sessions_on(date) from public, anon;
grant execute on function public.my_taught_sessions_on(date) to authenticated;

create or replace function public.my_active_course_classes()
returns table(course_class_id uuid, course_code text, course_name text)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_active_course_classes()
$$;
revoke execute on function public.my_active_course_classes() from public, anon;
grant execute on function public.my_active_course_classes() to authenticated;

-- my_face_profile_status juga di schema app (0015_research_views.sql) dan
-- dipakai FaceProfileRepository di Flutter - wrapper yang sama diperlukan.
create or replace function public.my_face_profile_status()
returns table(has_profile boolean, enrolled_at timestamptz, updated_at timestamptz, quality_score real, version integer)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_face_profile_status()
$$;
revoke execute on function public.my_face_profile_status() from public, anon;
grant execute on function public.my_face_profile_status() to authenticated;
