-- Data prodi sesuai struktur fakultas dari user (bukan migration schema -
-- ini data akademik, dijalankan manual lewat SQL Editor).

-- Faculties yang sudah ada (FTI) sebenarnya "Fakultas Ilmu Komputer" -
-- ganti nama/kode, BUKAN bikin fakultas baru (supaya TI/SI yang sudah ada
-- tidak duplikat).
update faculties
set name = 'Fakultas Ilmu Komputer', code = 'FIK'
where code = 'FTI';

-- Fakultas baru.
insert into faculties (name, code)
values ('Fakultas Komunikasi & Bisnis', 'FKB')
on conflict (code) do nothing;

-- Prodi tambahan di Fakultas Ilmu Komputer (Sains Data - TI & SI sudah ada).
insert into study_programs (faculty_id, code, name, degree_level)
select id, 'SADA', 'Sains Data', 'S1' from faculties where code = 'FIK'
on conflict (faculty_id, code) do nothing;

-- Prodi di Fakultas Komunikasi & Bisnis.
insert into study_programs (faculty_id, code, name, degree_level)
select id, v.code, v.name, 'S1'
from faculties, (values
  ('FTV', 'Film dan Televisi'),
  ('KWU', 'Kewirausahaan'),
  ('SANKOM', 'Sains Komunikasi')
) as v(code, name)
where faculties.code = 'FKB'
on conflict (faculty_id, code) do nothing;
