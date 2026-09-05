-- =============================================================================
-- Fitur koordinator kelas: input KRS & KHS mahasiswa di prodinya, dan info
-- meeting session (bukan reschedule/batal - itu tetap wewenang dosen) untuk
-- kelas yang diizinkan admin (data-driven lewat class_groups flag, BUKAN
-- hardcode "reguler malam"/"ekstensi" di kode - sesuai prinsip di seluruh
-- spec: jangan hardcode struktur akademik).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- KRS: tandai pengulangan matkul (satu-satunya pengecualian aturan semester)
-- dan validasi server-side bahwa matkul yang diambil memang matkul semester
-- berjalan mahasiswa, kecuali is_retake.
-- ---------------------------------------------------------------------------
alter table enrollments add column is_retake boolean not null default false;
-- Nilai terstruktur untuk KHS (huruf sudah ada di final_grade, tambah bobot).
alter table enrollments add column grade_point numeric(3,2) check (grade_point between 0 and 4);

create or replace function app.guard_enrollment_semester()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_course_semester smallint; v_student_semester smallint;
begin
  if current_setting('role', true) = 'service_role' or app.is_admin() then
    return new;
  end if;
  if new.is_retake then
    return new;
  end if;
  select c.semester into v_course_semester
    from public.course_classes cc join public.courses c on c.id = cc.course_id
    where cc.id = new.course_class_id;
  select s.current_semester into v_student_semester
    from public.students s where s.id = new.student_id;
  if v_course_semester is not null and v_student_semester is not null
     and v_course_semester <> v_student_semester then
    raise exception
      'Mata kuliah semester % tidak dapat diambil mahasiswa semester % (kecuali mengulang)',
      v_course_semester, v_student_semester using errcode = '23514';
  end if;
  return new;
end $$;
create trigger enrollments_guard_semester_trg
  before insert on enrollments
  for each row execute function app.guard_enrollment_semester();

-- Koordinator input KRS untuk mahasiswa di class_group-nya sendiri saja.
grant insert, update on enrollments to authenticated;

create policy enr_write_coordinator on enrollments for all to authenticated
  using (app.is_coordinator_of((select s.class_group_id from students s where s.id = enrollments.student_id)))
  with check (app.is_coordinator_of((select s.class_group_id from students s where s.id = enrollments.student_id)));

-- ---------------------------------------------------------------------------
-- KHS: dokumen resmi (link Drive, sudah ditandatangani Kepala Biro Akademik
-- & Administrasi) per mahasiswa per semester. Nilai per mata kuliah tetap
-- di enrollments.final_grade/grade_point - dokumen ini cuma metadata +
-- pointer ke Drive tempat mahasiswa unduh KHS resminya.
-- ---------------------------------------------------------------------------
create table khs_documents (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  academic_term_id uuid not null references academic_terms(id) on delete restrict,
  drive_link text not null,
  signed_by text not null, -- nama Kepala Biro Akademik & Administrasi
  status text not null default 'DISTRIBUTED' check (status in ('DRAFT', 'DISTRIBUTED')),
  uploaded_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, academic_term_id)
);
create index khs_documents_student_idx on khs_documents(student_id);

alter table khs_documents enable row level security;
alter table khs_documents force row level security;
revoke all on khs_documents from authenticated, anon;
grant select, insert, update on khs_documents to authenticated;

create policy khs_select_self on khs_documents for select to authenticated
  using (student_id = app.current_student_id());
create policy khs_select_coordinator on khs_documents for select to authenticated
  using (app.is_coordinator_of((select s.class_group_id from students s where s.id = khs_documents.student_id)));
create policy khs_select_admin on khs_documents for select to authenticated
  using (app.is_admin());
create policy khs_write_coordinator on khs_documents for all to authenticated
  using (app.is_coordinator_of((select s.class_group_id from students s where s.id = khs_documents.student_id)))
  with check (app.is_coordinator_of((select s.class_group_id from students s where s.id = khs_documents.student_id)));
create policy khs_write_admin on khs_documents for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

-- ---------------------------------------------------------------------------
-- Info meeting session oleh koordinator - hanya utk class_group yang
-- diizinkan admin (data-driven, bukan hardcode nama kelas). Koordinator
-- TIDAK bisa reschedule/batal - itu tetap lewat meeting_sessions yang cuma
-- boleh diubah dosen/admin (RLS existing di 0013 tidak diubah di sini).
-- ---------------------------------------------------------------------------
alter table class_groups add column allow_coordinator_session_notice boolean not null default false;

create table session_notices (
  id uuid primary key default gen_random_uuid(),
  meeting_session_id uuid not null references meeting_sessions(id) on delete cascade,
  class_group_id uuid not null references class_groups(id) on delete cascade,
  message text not null,
  created_by uuid not null references users(id),
  created_at timestamptz not null default now()
);
create index session_notices_session_idx on session_notices(meeting_session_id);

alter table session_notices enable row level security;
alter table session_notices force row level security;
revoke all on session_notices from authenticated, anon;
grant select, insert on session_notices to authenticated;

create policy session_notices_select on session_notices for select to authenticated
  using (
    app.is_admin()
    or app.teaches_session(meeting_session_id)
    or app.is_coordinator_of(class_group_id)
    or exists (
      select 1 from meeting_sessions ms where ms.id = session_notices.meeting_session_id
      and app.is_enrolled(ms.course_class_id)
    )
  );

create policy session_notices_insert_coordinator on session_notices for insert to authenticated
  with check (
    created_by = auth.uid()
    and app.is_coordinator_of(class_group_id)
    and (select cg.allow_coordinator_session_notice from class_groups cg where cg.id = class_group_id)
    and exists (
      select 1 from meeting_sessions ms join course_classes cc on cc.id = ms.course_class_id
      where ms.id = session_notices.meeting_session_id and cc.class_group_id = session_notices.class_group_id
    )
  );
