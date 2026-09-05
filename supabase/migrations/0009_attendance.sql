-- attendance_records = authoritative outcome, exactly one row per (student, session).
create table attendance_records (
  id                  uuid primary key default gen_random_uuid(),
  student_id          uuid not null references students(id) on delete cascade,
  meeting_session_id  uuid not null references meeting_sessions(id) on delete cascade,
  enrollment_id       uuid references enrollments(id) on delete set null,
  course_class_id     uuid not null references course_classes(id) on delete cascade,

  status              attendance_status not null,
  check_in_at         timestamptz,
  check_out_at        timestamptz,
  minutes_late        integer,

  latitude            double precision,
  longitude           double precision,
  gps_accuracy_m      real,
  gps_distance        double precision,
  geofence_radius_m   integer,
  geofence_source     text,
  face_similarity     real,
  face_threshold_used real,
  anti_spoof_score    real,
  anti_spoof_threshold_used real,
  verification_mode   verification_mode not null,
  risk_score          real not null default 0 check (risk_score between 0 and 1),
  risk_flags          text[] not null default '{}',

  check_out_latitude  double precision,
  check_out_longitude double precision,
  check_out_distance  double precision,

  device_info         jsonb not null default '{}'::jsonb,

  verification_id     uuid,
  attempt_count        smallint not null default 1,

  is_manual           boolean not null default false,
  overridden_by       uuid references users(id),
  overridden_at       timestamptz,
  override_reason     text,
  previous_status     attendance_status,

  leave_request_id    uuid,  -- FK added in 0010 (leave_requests created after)

  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint attendance_unique_per_session unique (student_id, meeting_session_id),
  constraint attendance_checkout_after_chk check (check_out_at is null or check_in_at is null
                                                  or check_out_at >= check_in_at),
  constraint attendance_override_chk check (
    overridden_by is null or (overridden_at is not null and override_reason is not null)
  )
);
create index attendance_student_idx         on attendance_records(student_id);
create index attendance_session_idx         on attendance_records(meeting_session_id);
create index attendance_course_class_idx    on attendance_records(course_class_id);
create index attendance_status_idx          on attendance_records(status);
create index attendance_checkin_idx         on attendance_records(check_in_at desc);
create index attendance_student_session_idx on attendance_records(student_id, meeting_session_id);
create index attendance_enrollment_idx      on attendance_records(enrollment_id);

-- attendance_verifications = append-only log of every attempt, pass or fail. The research dataset.
create table attendance_verifications (
  id                    uuid primary key default gen_random_uuid(),
  attendance_record_id  uuid references attendance_records(id) on delete set null,
  student_id            uuid not null references students(id) on delete cascade,
  meeting_session_id    uuid references meeting_sessions(id)  on delete set null,
  course_class_id       uuid references course_classes(id)    on delete set null,

  attempt_number        smallint not null default 1,
  outcome               verification_outcome not null,
  failure_stage         text,
  failure_reason        text,

  face_similarity       real,
  face_threshold_used   real,
  face_passed           boolean,
  anti_spoof_score      real,
  anti_spoof_threshold_used real,
  anti_spoof_passed     boolean,
  liveness_raw_score    real,
  embedding_norm        real,
  latitude              double precision,
  longitude             double precision,
  gps_accuracy_m        real,
  gps_distance          double precision,
  geofence_radius_m     integer,
  geofence_passed       boolean,
  window_passed         boolean,
  mode_passed           boolean,
  enrollment_passed     boolean,

  verification_mode     verification_mode not null,
  risk_score            real,
  risk_flags            text[] not null default '{}',
  client_reported_pass  boolean,
  server_decision       boolean not null,

  device_info           jsonb not null default '{}'::jsonb,
  app_version           text,
  model_versions        jsonb not null default '{}'::jsonb,
  processing_ms         integer,
  client_processing_ms  integer,
  challenge_id          uuid,
  details               jsonb not null default '{}'::jsonb,

  ground_truth_label    text check (ground_truth_label in ('GENUINE','SPOOF','IMPOSTOR','UNKNOWN')),
  labelled_by           uuid references users(id),
  labelled_at           timestamptz,
  experiment_tag        text,

  created_at            timestamptz not null default now()
);
create index av_student_idx     on attendance_verifications(student_id);
create index av_session_idx     on attendance_verifications(meeting_session_id);
create index av_outcome_idx     on attendance_verifications(outcome);
create index av_created_idx     on attendance_verifications(created_at desc);
create index av_record_idx      on attendance_verifications(attendance_record_id);
create index av_experiment_idx  on attendance_verifications(experiment_tag) where experiment_tag is not null;
create index av_label_idx       on attendance_verifications(ground_truth_label) where ground_truth_label is not null;

-- Anti-replay one-shot nonce, issued right before the camera opens.
create table attendance_challenges (
  id                 uuid primary key default gen_random_uuid(),
  student_id         uuid not null references students(id) on delete cascade,
  meeting_session_id uuid not null references meeting_sessions(id) on delete cascade,
  nonce              text not null unique,
  issued_at          timestamptz not null default now(),
  expires_at         timestamptz not null,
  consumed_at        timestamptz,
  consumed_by_verification_id uuid,
  client_ip          inet,
  device_id_hash     text
);
create index ac_student_session_idx on attendance_challenges(student_id, meeting_session_id);
create index ac_expiry_idx on attendance_challenges(expires_at) where consumed_at is null;
