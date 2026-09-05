-- Prevent a user from ever self-elevating role/status/username, even though
-- the UPDATE policy on `users` otherwise allows self-updates to the row.
create or replace function app.guard_user_privileged_columns()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('role', true) = 'service_role' or app.is_admin() then
    return new;
  end if;
  if new.role <> old.role then
    raise exception 'Role tidak dapat diubah sendiri' using errcode = '42501';
  end if;
  if new.status <> old.status or new.username <> old.username then
    raise exception 'Field terproteksi tidak dapat diubah' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger users_guard_privileged_trg
  before update on users
  for each row execute function app.guard_user_privileged_columns();

-- Students may not change their own academic identity columns.
create or replace function app.guard_student_privileged_columns()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('role', true) = 'service_role' or app.is_admin() then
    return new;
  end if;
  if new.nim <> old.nim or new.study_program_id <> old.study_program_id
     or new.class_group_id is distinct from old.class_group_id
     or new.academic_status <> old.academic_status or new.entry_year <> old.entry_year then
    raise exception 'Field akademik tidak dapat diubah sendiri' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger students_guard_privileged_trg
  before update on students
  for each row execute function app.guard_student_privileged_columns();

-- Lecturers cannot retroactively edit a closed past session (admin can).
create or replace function app.guard_meeting_session_edit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('role', true) = 'service_role' or app.is_admin() then
    return new;
  end if;
  if old.session_date < current_date and old.status = 'CLOSED' then
    raise exception 'Sesi yang sudah lampau dan ditutup tidak dapat diubah' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger meeting_sessions_guard_edit_trg
  before update on meeting_sessions
  for each row execute function app.guard_meeting_session_edit();

-- Lecturer override on attendance_records may only touch status/override
-- metadata/notes — never the evidence columns (already enforced by the RLS
-- WITH CHECK is_manual=true, but this trigger also blocks evidence tampering
-- even if a future policy change is looser than intended).
create or replace function app.guard_attendance_record_evidence()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('role', true) = 'service_role' then
    return new;
  end if;
  if new.face_similarity is distinct from old.face_similarity
     or new.anti_spoof_score is distinct from old.anti_spoof_score
     or new.gps_distance is distinct from old.gps_distance
     or new.geofence_radius_m is distinct from old.geofence_radius_m
     or new.risk_score is distinct from old.risk_score
     or new.verification_mode is distinct from old.verification_mode
     or new.check_in_at is distinct from old.check_in_at
     or new.verification_id is distinct from old.verification_id
     or new.latitude is distinct from old.latitude
     or new.longitude is distinct from old.longitude then
    if not app.is_admin() then
      raise exception 'Bukti presensi tidak dapat diubah' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger attendance_records_guard_evidence_trg
  before update on attendance_records
  for each row execute function app.guard_attendance_record_evidence();

-- attendance_verifications is append-only except for the research-labelling columns.
create or replace function app.guard_verification_label_only()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('role', true) = 'service_role' then
    return new;
  end if;
  if not app.is_admin() then
    raise exception 'Log verifikasi tidak dapat diubah' using errcode = '42501';
  end if;
  if new.outcome <> old.outcome or new.student_id <> old.student_id
     or new.face_similarity is distinct from old.face_similarity
     or new.anti_spoof_score is distinct from old.anti_spoof_score then
    raise exception 'Hanya kolom label penelitian yang dapat diubah' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger attendance_verifications_guard_trg
  before update on attendance_verifications
  for each row execute function app.guard_verification_label_only();

-- New auth.users row -> create the matching public.users row. Role is taken
-- ONLY from raw_app_meta_data (service-role-set) or a matching
-- provisioned_accounts entry -- raw_user_meta_data (client-writable) is
-- deliberately never consulted for role.
create or replace function app.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_role public.user_role; v_pa record; v_username text;
begin
  v_username := split_part(new.email, '@', 1);
  select * into v_pa from public.provisioned_accounts
   where username = v_username and claimed_at is null and expires_at > now();

  v_role := coalesce(
      nullif(new.raw_app_meta_data ->> 'role', '')::public.user_role,
      v_pa.role);

  if v_role is null then
    raise exception 'Akun tidak ter-provisioning. Hubungi admin.' using errcode = '42501';
  end if;

  insert into public.users (id, username, full_name, role, status, created_by)
  values (new.id, v_username,
          coalesce(new.raw_user_meta_data ->> 'full_name', v_pa.full_name, v_username),
          v_role, 'active', v_pa.created_by);

  if v_pa.id is not null then
    update public.provisioned_accounts
      set claimed_at = now(), claimed_user_id = new.id
      where id = v_pa.id;
  end if;

  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function app.handle_new_auth_user();
