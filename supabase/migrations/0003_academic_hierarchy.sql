create table faculties (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  name       text not null,
  dean_name  text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table study_programs (
  id               uuid primary key default gen_random_uuid(),
  faculty_id       uuid not null references faculties(id) on delete restrict,
  code             text not null,
  name             text not null,
  degree_level     text not null default 'S1' check (degree_level in ('D3','D4','S1','S2','S3')),
  head_lecturer_id uuid,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (faculty_id, code)
);
create index study_programs_faculty_idx on study_programs(faculty_id);

create table class_groups (
  id                   uuid primary key default gen_random_uuid(),
  study_program_id     uuid not null references study_programs(id) on delete restrict,
  class_type_id        uuid not null references ref_class_types(id) on delete restrict,
  code                 text not null,
  name                 text not null,
  entry_year           smallint not null,
  current_semester     smallint check (current_semester between 1 and 14),
  advisor_lecturer_id  uuid,
  capacity             smallint,
  is_active            boolean not null default true,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (study_program_id, code, entry_year)
);
create index class_groups_program_idx on class_groups(study_program_id);
