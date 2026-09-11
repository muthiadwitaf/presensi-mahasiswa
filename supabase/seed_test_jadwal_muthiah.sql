do $$
declare
  v_student_id       uuid;
  v_study_program_id uuid;
  v_class_group_id   uuid;
  v_term_id          uuid;
  v_course_id        uuid;
  v_course_class_id  uuid;
  r record;
begin
  select id, study_program_id, class_group_id
    into v_student_id, v_study_program_id, v_class_group_id
  from students where nim = '2301030013';

  if v_student_id is null then
    raise exception 'Mahasiswa dengan NIM 2301030013 tidak ditemukan - pastikan akun sudah pernah login/register sebelum menjalankan script ini';
  end if;

  select id into v_term_id from academic_terms where code = '2025/2026-GENAP';
  if v_term_id is null then
    insert into academic_terms (code, academic_year, semester_type, start_date, end_date, is_active)
    values ('2025/2026-GENAP', '2025/2026', 'GENAP', '2026-02-01', '2026-07-31', false)
    returning id into v_term_id;
  end if;

  for r in
    select * from (values
      (2, 'FIK010406-TEST', 'DATAWAREHOUSE', 3, 'Dora Bernadisman, S.Kom., M.Kom., M.M.'),
      (3, 'FIK010206-TEST', 'ETIKA PROFESI ISLAM', 2, 'Faiz Rafdhi, S.Kom., M.Kom'),
      (4, 'FIK010804-TEST', 'SEMINAR PROPOSAL SKRIPSI', 2, 'Prodi'),
      (5, 'FIK010417-TEST', 'BIG DATA ANALYTIC', 3, 'Nina Meliana, S.Kom., M.Kom'),
      (2, 'FIK010307-TEST', 'PEMROGRAMAN IV', 3, 'Aris Prasetyo, S.Kom'),
      (3, 'FIK010608-TEST', 'ENTERPRISE ARCHITECTURE', 3, 'Dr. Faiz Rafdhi, S.Kom., M.Kom'),
      (4, 'FIK010605-TEST', 'SISTEM TERDISTRIBUSI', 3, 'Tarsino Amijoyo, S.Kom., M.Kom')
    ) as v(day_of_week, kode_mk, nama_mk, sks, nama_dosen)
  loop
    insert into courses (study_program_id, code, name, credits, semester)
    values (v_study_program_id, r.kode_mk, r.nama_mk, r.sks, 6)
    on conflict (study_program_id, code) do update set name = excluded.name
    returning id into v_course_id;

    insert into course_classes (course_id, academic_term_id, class_group_id, code, name, default_mode, default_meeting_url, primary_lecturer_name)
    values (v_course_id, v_term_id, v_class_group_id, r.kode_mk, r.nama_mk, 'ONLINE', 'https://meet.google.com/test-kelas-malam', r.nama_dosen)
    on conflict (academic_term_id, code) do update set name = excluded.name, primary_lecturer_name = excluded.primary_lecturer_name
    returning id into v_course_class_id;

    insert into schedules (course_class_id, day_of_week, start_time, end_time, mode, meeting_url)
    select v_course_class_id, r.day_of_week, '18:30', '20:30', 'ONLINE', 'https://meet.google.com/test-kelas-malam'
    where not exists (
      select 1 from schedules where course_class_id = v_course_class_id and day_of_week = r.day_of_week
    );

    insert into enrollments (student_id, course_class_id, academic_term_id, status)
    values (v_student_id, v_course_class_id, v_term_id, 'ACTIVE')
    on conflict (student_id, course_class_id, academic_term_id) do update set status = 'ACTIVE';
  end loop;
end $$;
