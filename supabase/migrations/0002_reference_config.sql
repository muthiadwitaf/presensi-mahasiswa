create table app_settings (
  key           text primary key,
  value         jsonb        not null,
  value_type    text         not null check (value_type in ('number','string','boolean','json')),
  description   text,
  is_public     boolean      not null default false,
  updated_by    uuid,
  updated_at    timestamptz  not null default now()
);

create table ref_days (
  day_of_week smallint primary key check (day_of_week between 1 and 7),
  code        text not null unique,
  label_id    text not null,
  label_en    text not null,
  is_weekend  boolean not null default false,
  sort_order  smallint not null
);

create table ref_class_types (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  label       text not null,
  description text,
  is_active   boolean not null default true,
  sort_order  smallint not null default 0
);

create table academic_terms (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  academic_year text not null,
  semester_type text not null check (semester_type in ('GANJIL','GENAP','PENDEK')),
  start_date    date not null,
  end_date      date not null,
  is_active     boolean not null default false,
  created_at    timestamptz not null default now(),
  constraint academic_terms_range_chk check (end_date > start_date)
);
create unique index academic_terms_one_active_idx
  on academic_terms ((is_active)) where is_active;

insert into ref_days (day_of_week, code, label_id, label_en, is_weekend, sort_order) values
  (1,'MON','Senin','Monday',false,1),
  (2,'TUE','Selasa','Tuesday',false,2),
  (3,'WED','Rabu','Wednesday',false,3),
  (4,'THU','Kamis','Thursday',false,4),
  (5,'FRI','Jumat','Friday',false,5),
  (6,'SAT','Sabtu','Saturday',true,6),
  (7,'SUN','Minggu','Sunday',true,7);

insert into ref_class_types (code, label, description, sort_order) values
  ('REGULER','Reguler','Kelas reguler pagi',1),
  ('REGULER_MALAM','Reguler Malam','Kelas reguler malam',2),
  ('EKSTENSI','Ekstensi','Kelas ekstensi/karyawan',3);

insert into app_settings (key, value, value_type, description, is_public) values
  ('campus_latitude', '-6.302', 'number', 'Latitude pusat kampus (placeholder, tolong diperbarui)', false),
  ('campus_longitude', '106.652', 'number', 'Longitude pusat kampus (placeholder, tolong diperbarui)', false),
  ('geofence_radius_meters', '150', 'number', 'Radius default geofence kampus (meter)', false),
  ('geofence_gps_accuracy_max_meters', '50', 'number', 'Akurasi GPS maksimum yang diterima', false),
  ('face_match_threshold', '0.5', 'number', 'Threshold jarak Euclidean pencocokan wajah', false),
  ('face_match_metric', '"euclidean"', 'string', 'Metrik pencocokan wajah', false),
  ('anti_spoof_threshold', '0.5', 'number', 'Threshold skor anti-spoof', false),
  ('anti_spoof_real_is_high_score', 'true', 'boolean', 'Arah label model anti-spoof', false),
  ('checkin_open_before_minutes', '15', 'number', 'Menit sebelum sesi mulai, Clock In dibuka', true),
  ('checkin_close_after_minutes', '30', 'number', 'Menit setelah sesi mulai, Clock In ditutup', true),
  ('late_after_minutes', '15', 'number', 'Menit setelah sesi mulai dianggap terlambat', true),
  ('checkout_required', 'false', 'boolean', 'Apakah Clock Out wajib', true),
  ('campus_timezone', '"Asia/Jakarta"', 'string', 'Timezone kampus', true),
  ('allow_online_geofence_bypass', 'true', 'boolean', 'Sesi ONLINE melewati geofence', true),
  ('max_challenge_ttl_seconds', '120', 'number', 'Masa berlaku nonce presensi (detik)', false),
  ('require_device_binding', 'false', 'boolean', 'Wajib device binding', false),
  ('face_enroll_min_quality', '0.5', 'number', 'Skor kualitas minimum saat daftar wajah', false),
  ('face_enroll_cooldown_hours', '24', 'number', 'Jeda minimum antar pendaftaran ulang wajah', false),
  ('risk_reject_threshold', '0.85', 'number', 'Ambang risk_score untuk auto-tolak', false),
  ('risk_review_threshold', '0.6', 'number', 'Ambang risk_score untuk ditandai review dosen', false);
