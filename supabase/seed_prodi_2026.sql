update faculties
set name = 'Fakultas Ilmu Komputer', code = 'FIK'
where code = 'FTI';

insert into faculties (name, code)
values ('Fakultas Komunikasi & Bisnis', 'FKB')
on conflict (code) do nothing;

insert into study_programs (faculty_id, code, name, degree_level)
select id, 'SADA', 'Sains Data', 'S1' from faculties where code = 'FIK'
on conflict (faculty_id, code) do nothing;

insert into study_programs (faculty_id, code, name, degree_level)
select id, v.code, v.name, 'S1'
from faculties, (values
  ('FTV', 'Film dan Televisi'),
  ('KWU', 'Kewirausahaan'),
  ('SANKOM', 'Sains Komunikasi')
) as v(code, name)
where faculties.code = 'FKB'
on conflict (faculty_id, code) do nothing;
