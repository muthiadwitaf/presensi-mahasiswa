create or replace function app.current_student_id() returns uuid
language sql stable security definer set search_path = '' set row_security = off as
$$ select s.id from public.students s where s.user_id = auth.uid() $$;

create or replace function app.current_lecturer_id() returns uuid
language sql stable security definer set search_path = '' set row_security = off as
$$ select l.id from public.lecturers l where l.user_id = auth.uid() $$;

create or replace function app.teaches_class(p_cc uuid) returns boolean
language sql stable security definer set search_path = '' set row_security = off as $$
  select exists (
    select 1 from public.course_class_lecturers ccl
    where ccl.course_class_id = p_cc
      and ccl.lecturer_id = app.current_lecturer_id()
  )
$$;

create or replace function app.is_enrolled(p_cc uuid) returns boolean
language sql stable security definer set search_path = '' set row_security = off as $$
  select exists (
    select 1 from public.enrollments e
    where e.course_class_id = p_cc
      and e.student_id = app.current_student_id()
      and e.status = 'ACTIVE'
  )
$$;

create or replace function app.teaches_session(p_session uuid) returns boolean
language sql stable security definer set search_path = '' set row_security = off as $$
  select exists (
    select 1 from public.meeting_sessions ms
    join public.course_class_lecturers ccl on ccl.course_class_id = ms.course_class_id
    where ms.id = p_session and ccl.lecturer_id = app.current_lecturer_id()
  )
$$;

create or replace function app.current_role() returns user_role
language plpgsql stable security definer set search_path = '' set row_security = off as $$
declare r text;
begin
  r := coalesce(
        nullif(current_setting('request.jwt.claims', true)::jsonb #>> '{app_metadata,role}',''),
        nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'role','')
      );
  if r is null then
    select u.role::text into r from public.users u where u.id = auth.uid();
  end if;
  return r::public.user_role;
exception when others then return null;
end $$;
