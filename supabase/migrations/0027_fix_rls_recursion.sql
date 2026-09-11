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
    execute format('alter table %I no force row level security', t);
  end loop;
end $$;

alter table role_assignments no force row level security;
alter table khs_documents no force row level security;
alter table session_notices no force row level security;
