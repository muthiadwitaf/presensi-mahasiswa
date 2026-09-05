create table courses (
  id               uuid primary key default gen_random_uuid(),
  study_program_id uuid not null references study_programs(id) on delete restrict,
  code             text not null,
  name             text not null,
  credits          smallint not null check (credits between 0 and 12),
  semester         smallint check (semester between 1 and 14),
  course_type      text not null default 'WAJIB' check (course_type in ('WAJIB','PILIHAN','MKDU')),
  description      text,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (study_program_id, code)
);
create index courses_program_idx on courses(study_program_id);

-- A concrete offering: this course, this term, this class group, this lecturer.
create table course_classes (
  id                  uuid primary key default gen_random_uuid(),
  course_id           uuid not null references courses(id) on delete restrict,
  academic_term_id    uuid not null references academic_terms(id) on delete restrict,
  class_group_id      uuid references class_groups(id) on delete set null,
  primary_lecturer_id uuid references lecturers(id) on delete set null,
  code                text not null,
  name                text,
  default_mode        delivery_mode not null default 'OFFLINE',
  default_location_id uuid references locations(id) on delete set null,
  default_meeting_url text,
  quota               smallint,
  total_meetings      smallint not null default 16,
  min_attendance_pct  smallint not null default 75 check (min_attendance_pct between 0 and 100),
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (academic_term_id, code)
);
create index course_classes_course_idx   on course_classes(course_id);
create index course_classes_term_idx     on course_classes(academic_term_id);
create index course_classes_lecturer_idx on course_classes(primary_lecturer_id);
create index course_classes_group_idx    on course_classes(class_group_id);

-- Team teaching + the RLS source of truth for "who may manage this class".
create table course_class_lecturers (
  course_class_id uuid not null references course_classes(id) on delete cascade,
  lecturer_id     uuid not null references lecturers(id) on delete cascade,
  role_in_class   text not null default 'PENGAMPU'
                    check (role_in_class in ('PENGAMPU','PENDAMPING','ASISTEN')),
  can_manage_sessions boolean not null default true,
  created_at      timestamptz not null default now(),
  primary key (course_class_id, lecturer_id)
);
create index cc_lecturers_lecturer_idx on course_class_lecturers(lecturer_id);

-- Keep the junction table in sync whenever primary_lecturer_id is set.
create or replace function app.sync_primary_lecturer() returns trigger
language plpgsql as $$
begin
  if new.primary_lecturer_id is not null then
    insert into course_class_lecturers (course_class_id, lecturer_id, role_in_class)
    values (new.id, new.primary_lecturer_id, 'PENGAMPU')
    on conflict (course_class_id, lecturer_id) do nothing;
  end if;
  return new;
end $$;
create trigger course_classes_sync_lecturer
  after insert or update of primary_lecturer_id on course_classes
  for each row execute function app.sync_primary_lecturer();
