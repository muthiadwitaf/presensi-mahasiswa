create table users (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text not null unique,
  full_name     text not null,
  role          user_role not null,
  status        user_status not null default 'active',
  email         text,
  phone         text,
  avatar_path   text,
  last_login_at timestamptz,
  created_by    uuid references users(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index users_role_idx   on users(role) where status = 'active';
create index users_status_idx on users(status);

create table students (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null unique references users(id) on delete cascade,
  nim              text not null unique,
  full_name        text not null,
  study_program_id uuid not null references study_programs(id) on delete restrict,
  class_group_id   uuid references class_groups(id) on delete set null,
  entry_year       smallint not null,
  current_semester smallint,
  academic_status  text not null default 'AKTIF'
                     check (academic_status in ('AKTIF','CUTI','LULUS','DO','NONAKTIF')),
  guardian_phone   text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index students_user_id_idx     on students(user_id);
create index students_class_group_idx on students(class_group_id);
create index students_program_idx     on students(study_program_id);
create index students_nim_idx         on students(nim);

create table lecturers (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null unique references users(id) on delete cascade,
  nip              text not null unique,
  nidn             text unique,
  full_name        text not null,
  front_title      text,
  back_title       text,
  faculty_id       uuid references faculties(id) on delete set null,
  study_program_id uuid references study_programs(id) on delete set null,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index lecturers_user_id_idx on lecturers(user_id);
create index lecturers_program_idx on lecturers(study_program_id);

alter table study_programs add constraint study_programs_head_fk
  foreign key (head_lecturer_id) references lecturers(id) on delete set null;
alter table class_groups add constraint class_groups_advisor_fk
  foreign key (advisor_lecturer_id) references lecturers(id) on delete set null;

create table face_profiles (
  id                 uuid primary key default gen_random_uuid(),
  student_id         uuid not null unique references students(id) on delete cascade,
  embedding          real[] not null,
  embedding_dim      smallint not null default 192,
  embedding_model    text not null default 'mobilefacenet-v1',
  photo_path         text,
  photo_hash         text,
  quality_score      real,
  enrolled_at        timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  updated_by         uuid references users(id),
  version            integer not null default 1,
  is_active          boolean not null default true,
  constraint face_embedding_dim_chk check (array_length(embedding,1) = embedding_dim)
);
create index face_profiles_student_idx on face_profiles(student_id);

create table face_profile_history (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references students(id) on delete cascade,
  version     integer not null,
  embedding   real[] not null,
  photo_path  text,
  replaced_at timestamptz not null default now(),
  replaced_by uuid references users(id),
  reason      text
);
