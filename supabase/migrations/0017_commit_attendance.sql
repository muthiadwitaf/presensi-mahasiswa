-- Atomically writes the PASS verification + the authoritative attendance
-- record + consumes the challenge. Called only by submit-attendance via the
-- service role (SECURITY DEFINER so it can also be safe if ever exposed).
create or replace function app.commit_attendance(
  p_student_id uuid,
  p_meeting_session_id uuid,
  p_enrollment_id uuid,
  p_course_class_id uuid,
  p_status attendance_status,
  p_minutes_late integer,
  p_verification_mode verification_mode,
  p_latitude double precision,
  p_longitude double precision,
  p_gps_accuracy_m real,
  p_gps_distance double precision,
  p_geofence_radius_m integer,
  p_geofence_source text,
  p_face_similarity real,
  p_face_threshold real,
  p_anti_spoof_score real,
  p_anti_spoof_threshold real,
  p_risk_score real,
  p_risk_flags text[],
  p_device_info jsonb,
  p_challenge_id uuid,
  p_app_version text,
  p_model_versions jsonb,
  p_client_processing_ms integer,
  p_processing_ms integer,
  p_experiment_tag text
) returns table(attendance_id uuid, verification_id uuid)
language plpgsql security definer set search_path = '' as $$
declare v_verification_id uuid; v_attendance_id uuid;
begin
  insert into public.attendance_verifications (
    student_id, meeting_session_id, course_class_id, outcome,
    face_similarity, face_threshold_used, face_passed,
    anti_spoof_score, anti_spoof_threshold_used, anti_spoof_passed,
    latitude, longitude, gps_accuracy_m, gps_distance, geofence_radius_m, geofence_passed,
    window_passed, mode_passed, enrollment_passed,
    verification_mode, risk_score, risk_flags, server_decision,
    device_info, app_version, model_versions, processing_ms, client_processing_ms,
    challenge_id, experiment_tag
  ) values (
    p_student_id, p_meeting_session_id, p_course_class_id, 'PASS',
    p_face_similarity, p_face_threshold, true,
    p_anti_spoof_score, p_anti_spoof_threshold, true,
    p_latitude, p_longitude, p_gps_accuracy_m, p_gps_distance, p_geofence_radius_m, true,
    true, true, true,
    p_verification_mode, p_risk_score, p_risk_flags, true,
    p_device_info, p_app_version, p_model_versions, p_processing_ms, p_client_processing_ms,
    p_challenge_id, p_experiment_tag
  ) returning id into v_verification_id;

  insert into public.attendance_records (
    student_id, meeting_session_id, enrollment_id, course_class_id, status,
    check_in_at, minutes_late, latitude, longitude, gps_accuracy_m, gps_distance,
    geofence_radius_m, geofence_source, face_similarity, face_threshold_used,
    anti_spoof_score, anti_spoof_threshold_used, verification_mode, risk_score,
    risk_flags, device_info, verification_id
  ) values (
    p_student_id, p_meeting_session_id, p_enrollment_id, p_course_class_id, p_status,
    now(), p_minutes_late, p_latitude, p_longitude, p_gps_accuracy_m, p_gps_distance,
    p_geofence_radius_m, p_geofence_source, p_face_similarity, p_face_threshold,
    p_anti_spoof_score, p_anti_spoof_threshold, p_verification_mode, p_risk_score,
    p_risk_flags, p_device_info, v_verification_id
  )
  on conflict (student_id, meeting_session_id) do nothing
  returning id into v_attendance_id;

  if v_attendance_id is null then
    -- Race lost to a concurrent duplicate submission: return the existing record idempotently.
    select id into v_attendance_id from public.attendance_records
      where student_id = p_student_id and meeting_session_id = p_meeting_session_id;
  else
    update public.attendance_verifications set attendance_record_id = v_attendance_id where id = v_verification_id;
    if p_challenge_id is not null then
      update public.attendance_challenges
        set consumed_at = now(), consumed_by_verification_id = v_verification_id
        where id = p_challenge_id;
    end if;
    update public.meeting_sessions set status = 'ONGOING'
      where id = p_meeting_session_id and status = 'SCHEDULED';
  end if;

  return query select v_attendance_id, v_verification_id;
end $$;

revoke execute on function app.commit_attendance from public, anon, authenticated;

-- Logs a FAILED verification attempt (any stage). Called by submit-attendance
-- via the service role for every rejected submission, so the research
-- dataset captures failures, not just successes.
create or replace function app.log_failed_verification(
  p_student_id uuid,
  p_meeting_session_id uuid,
  p_course_class_id uuid,
  p_outcome verification_outcome,
  p_failure_stage text,
  p_failure_reason text,
  p_face_similarity real,
  p_anti_spoof_score real,
  p_gps_distance double precision,
  p_verification_mode verification_mode,
  p_risk_score real,
  p_risk_flags text[],
  p_client_reported_pass boolean,
  p_device_info jsonb,
  p_app_version text,
  p_model_versions jsonb,
  p_processing_ms integer,
  p_client_processing_ms integer,
  p_experiment_tag text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  insert into public.attendance_verifications (
    student_id, meeting_session_id, course_class_id, outcome, failure_stage, failure_reason,
    face_similarity, anti_spoof_score, gps_distance, verification_mode, risk_score, risk_flags,
    client_reported_pass, server_decision, device_info, app_version, model_versions,
    processing_ms, client_processing_ms, experiment_tag
  ) values (
    p_student_id, p_meeting_session_id, p_course_class_id, p_outcome, p_failure_stage, p_failure_reason,
    p_face_similarity, p_anti_spoof_score, p_gps_distance, p_verification_mode, p_risk_score, p_risk_flags,
    p_client_reported_pass, false, p_device_info, p_app_version, p_model_versions,
    p_processing_ms, p_client_processing_ms, p_experiment_tag
  ) returning id into v_id;
  return v_id;
end $$;

revoke execute on function app.log_failed_verification from public, anon, authenticated;
