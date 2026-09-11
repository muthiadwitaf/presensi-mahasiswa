create table enrollments (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid not null references students(id) on delete cascade,
  course_class_id  uuid not null references course_classes(id) on delete cascade,
  academic_term_id uuid not null references academic_terms(id) on delete restrict,
  status           enrollment_status not null default 'ACTIVE',
  enrolled_at      timestamptz not null default now(),
  enrolled_by      uuid references users(id),
  dropped_at       timestamptz,
  final_grade      text,
  attendance_pct   numeric(5,2),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint enrollments_unique_krs unique (student_id, course_class_id, academic_term_id)
);
create index enrollments_student_idx      on enrollments(student_id);
create index enrollments_course_class_idx on enrollments(course_class_id);
create index enrollments_term_idx         on enrollments(academic_term_id);
create index enrollments_active_idx
  on enrollments(student_id, course_class_id) where status = 'ACTIVE';

create or replace function app.enrollments_sync_term() returns trigger
language plpgsql as $$
begin
  select academic_term_id into new.academic_term_id
  from course_classes where id = new.course_class_id;
  return new;
end $$;
create trigger enrollments_sync_term_trg
  before insert or update of course_class_id on enrollments
  for each row execute function app.enrollments_sync_term();
