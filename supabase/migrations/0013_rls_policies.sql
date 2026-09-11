do $$
declare t text;
begin
  for t in select unnest(array[
    'users','students','lecturers','face_profiles','face_profile_history',
    'faculties','study_programs','class_groups','ref_class_types','ref_days','academic_terms',
    'locations','courses','course_classes','course_class_lecturers','enrollments',
    'schedules','meeting_sessions','attendance_records','attendance_verifications','attendance_challenges',
    'leave_requests','notifications','notification_recipients','app_settings',
    'audit_logs','device_bindings','provisioned_accounts'
  ]) loop
    execute format('alter table %I enable row level security', t);
    execute format('alter table %I force row level security', t);
  end loop;
end $$;

revoke all on all tables in schema public from authenticated, anon;

grant select, update on users to authenticated;

create policy users_select_self on users for select to authenticated
  using (id = auth.uid());
create policy users_select_admin on users for select to authenticated
  using (app.is_admin());
create policy users_select_lecturer_own_students on users for select to authenticated
  using (app.is_lecturer() and exists (
    select 1 from students s join enrollments e on e.student_id = s.id
    where s.user_id = users.id and app.teaches_class(e.course_class_id)
  ));
create policy users_update_self_profile on users for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy users_all_admin on users for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select, update on students to authenticated;

create policy students_select_self on students for select to authenticated
  using (user_id = auth.uid());
create policy students_select_lecturer on students for select to authenticated
  using (app.is_lecturer() and exists (
    select 1 from enrollments e where e.student_id = students.id
    and e.status = 'ACTIVE' and app.teaches_class(e.course_class_id)
  ));
create policy students_select_admin on students for select to authenticated
  using (app.is_admin());
create policy students_update_self_limited on students for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy students_write_admin on students for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select on lecturers to authenticated;

create policy lecturers_select_all on lecturers for select to authenticated using (true);
create policy lecturers_write_admin on lecturers for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select on face_profiles to authenticated;
create policy face_select_admin on face_profiles for select to authenticated
  using (app.is_admin());
create policy face_write_admin on face_profiles for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select on face_profile_history to authenticated;
create policy face_history_admin on face_profile_history for select to authenticated
  using (app.is_admin());

do $$
declare t text;
begin
  for t in select unnest(array['faculties','study_programs','class_groups','ref_class_types','ref_days','academic_terms','courses']) loop
    execute format('grant select on %I to authenticated', t);
    execute format('create policy %I_select_all_auth on %I for select to authenticated using (true)', t, t);
    execute format('create policy %I_write_admin on %I for all to authenticated using (app.is_admin()) with check (app.is_admin())', t, t);
  end loop;
end $$;

grant select (id, parent_id, kind, code, name, building, floor, capacity, is_active, created_at, updated_at)
  on locations to authenticated;

create policy locations_select_masked on locations for select to authenticated using (true);
create policy locations_write_admin on locations for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

create or replace function app.locations_full() returns setof locations
language sql stable security definer set search_path = '' as $$
  select * from public.locations where app.is_admin() or app.is_lecturer()
$$;
revoke execute on function app.locations_full() from public, anon;
grant execute on function app.locations_full() to authenticated;

grant select, update on course_classes to authenticated;

create policy cc_select_enrolled on course_classes for select to authenticated
  using (app.is_enrolled(id));
create policy cc_select_lecturer on course_classes for select to authenticated
  using (app.teaches_class(id));
create policy cc_select_admin on course_classes for select to authenticated
  using (app.is_admin());
create policy cc_write_admin on course_classes for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select on course_class_lecturers to authenticated;
create policy ccl_select_visible on course_class_lecturers for select to authenticated
  using (app.teaches_class(course_class_id) or app.is_enrolled(course_class_id) or app.is_admin());
create policy ccl_write_admin on course_class_lecturers for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select on enrollments to authenticated;

create policy enr_select_self on enrollments for select to authenticated
  using (student_id = app.current_student_id());
create policy enr_select_lecturer on enrollments for select to authenticated
  using (app.teaches_class(course_class_id));
create policy enr_select_admin on enrollments for select to authenticated
  using (app.is_admin());
create policy enr_write_admin on enrollments for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select on schedules to authenticated;

create policy sch_select_enrolled on schedules for select to authenticated
  using (app.is_enrolled(course_class_id));
create policy sch_select_lecturer on schedules for select to authenticated
  using (app.teaches_class(course_class_id));
create policy sch_select_admin on schedules for select to authenticated
  using (app.is_admin());
create policy sch_write_admin on schedules for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select, insert, update on meeting_sessions to authenticated;

create policy ms_select_enrolled on meeting_sessions for select to authenticated
  using (app.is_enrolled(course_class_id));
create policy ms_select_lecturer on meeting_sessions for select to authenticated
  using (app.teaches_class(course_class_id));
create policy ms_select_admin on meeting_sessions for select to authenticated
  using (app.is_admin());
create policy ms_insert_lecturer on meeting_sessions for insert to authenticated
  with check (app.teaches_class(course_class_id) and created_by = auth.uid());
create policy ms_update_lecturer on meeting_sessions for update to authenticated
  using (app.teaches_class(course_class_id)) with check (app.teaches_class(course_class_id));
create policy ms_all_admin on meeting_sessions for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select, update on attendance_records to authenticated;

create policy ar_select_self on attendance_records for select to authenticated
  using (student_id = app.current_student_id());
create policy ar_select_lecturer on attendance_records for select to authenticated
  using (app.teaches_class(course_class_id));
create policy ar_select_admin on attendance_records for select to authenticated
  using (app.is_admin());
create policy ar_update_lecturer_override on attendance_records for update to authenticated
  using (app.teaches_class(course_class_id))
  with check (app.teaches_class(course_class_id) and is_manual = true and overridden_by = auth.uid());
create policy ar_update_admin on attendance_records for update to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select, update on attendance_verifications to authenticated;

create policy av_select_self on attendance_verifications for select to authenticated
  using (student_id = app.current_student_id());
create policy av_select_lecturer on attendance_verifications for select to authenticated
  using (app.teaches_class(course_class_id));
create policy av_select_admin on attendance_verifications for select to authenticated
  using (app.is_admin());
create policy av_update_label_admin on attendance_verifications for update to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select, insert, update on leave_requests to authenticated;

create policy lr_select_self on leave_requests for select to authenticated
  using (student_id = app.current_student_id());
create policy lr_insert_self on leave_requests for insert to authenticated
  with check (
    student_id = app.current_student_id() and status = 'PENDING'
    and reviewed_by is null and reviewed_at is null
    and (meeting_session_id is null or app.is_enrolled(
      (select course_class_id from meeting_sessions where id = meeting_session_id)))
  );
create policy lr_update_self_pending on leave_requests for update to authenticated
  using (student_id = app.current_student_id() and status = 'PENDING')
  with check (student_id = app.current_student_id() and status in ('PENDING','CANCELLED'));
create policy lr_select_lecturer on leave_requests for select to authenticated
  using (app.teaches_class(course_class_id) or app.teaches_session(meeting_session_id));
create policy lr_review_lecturer on leave_requests for update to authenticated
  using (app.teaches_class(course_class_id) or app.teaches_session(meeting_session_id))
  with check (reviewed_by = auth.uid() and status in ('APPROVED','REJECTED'));
create policy lr_all_admin on leave_requests for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select, insert on notifications to authenticated;

create policy notif_select_targeted on notifications for select to authenticated
  using (
    published_at <= now() and (expires_at is null or expires_at > now())
    and (
      (target_role is null and target_study_program_id is null and target_class_group_id is null and target_course_class_id is null)
      or target_role = app.current_role()
      or target_class_group_id = (select class_group_id from students where user_id = auth.uid())
      or target_study_program_id = (select study_program_id from students where user_id = auth.uid())
      or (target_course_class_id is not null and (app.is_enrolled(target_course_class_id) or app.teaches_class(target_course_class_id)))
      or exists (select 1 from notification_recipients nr where nr.notification_id = notifications.id and nr.user_id = auth.uid())
    )
  );
create policy notif_insert_lecturer on notifications for insert to authenticated
  with check (
    (app.is_lecturer() and target_course_class_id is not null and app.teaches_class(target_course_class_id) and created_by = auth.uid())
    or app.is_admin()
  );
create policy notif_all_admin on notifications for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select, insert, update on notification_recipients to authenticated;
create policy nr_select_self on notification_recipients for select to authenticated
  using (user_id = auth.uid());
create policy nr_insert_self on notification_recipients for insert to authenticated
  with check (user_id = auth.uid());
create policy nr_update_self on notification_recipients for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select on app_settings to authenticated;

create policy settings_select_public on app_settings for select to authenticated
  using (is_public = true);
create policy settings_select_admin on app_settings for select to authenticated
  using (app.is_admin());
create policy settings_write_admin on app_settings for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

grant select on audit_logs to authenticated;
create policy audit_select_admin on audit_logs for select to authenticated
  using (app.is_admin());

grant select on device_bindings to authenticated;
create policy device_bindings_admin on device_bindings for all to authenticated
  using (app.is_admin()) with check (app.is_admin());
create policy device_bindings_select_self on device_bindings for select to authenticated
  using (user_id = auth.uid());

grant select on provisioned_accounts to authenticated;
create policy provisioned_accounts_admin on provisioned_accounts for all to authenticated
  using (app.is_admin()) with check (app.is_admin());
