create or replace function app.student_class_group_id(p_student_id uuid) returns uuid
language sql stable security definer set search_path = '' set row_security = off as
$$ select s.class_group_id from public.students s where s.id = p_student_id $$;

drop policy if exists enr_write_coordinator on enrollments;
create policy enr_write_coordinator on enrollments for all to authenticated
  using (app.is_coordinator_of(app.student_class_group_id(enrollments.student_id)))
  with check (app.is_coordinator_of(app.student_class_group_id(enrollments.student_id)));

drop policy if exists khs_select_coordinator on khs_documents;
create policy khs_select_coordinator on khs_documents for select to authenticated
  using (app.is_coordinator_of(app.student_class_group_id(khs_documents.student_id)));
drop policy if exists khs_write_coordinator on khs_documents;
create policy khs_write_coordinator on khs_documents for all to authenticated
  using (app.is_coordinator_of(app.student_class_group_id(khs_documents.student_id)))
  with check (app.is_coordinator_of(app.student_class_group_id(khs_documents.student_id)));

create or replace function app.lecturer_teaches_user(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' set row_security = off as $$
  select exists (
    select 1 from public.students s join public.enrollments e on e.student_id = s.id
    where s.user_id = p_user_id and app.teaches_class(e.course_class_id)
  )
$$;

drop policy if exists users_select_lecturer_own_students on users;
create policy users_select_lecturer_own_students on users for select to authenticated
  using (app.is_lecturer() and app.lecturer_teaches_user(users.id));
