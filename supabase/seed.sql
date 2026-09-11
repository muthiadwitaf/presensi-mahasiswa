insert into academic_terms (code, academic_year, semester_type, start_date, end_date, is_active)
values ('2025/2026-GANJIL', '2025/2026', 'GANJIL', '2025-09-01', '2026-01-31', true);

insert into faculties (code, name) values ('FTI', 'Fakultas Teknologi Informasi');

insert into study_programs (faculty_id, code, name, degree_level)
select id, 'TI', 'Teknik Informatika', 'S1' from faculties where code = 'FTI';
insert into study_programs (faculty_id, code, name, degree_level)
select id, 'SI', 'Sistem Informasi', 'S1' from faculties where code = 'FTI';

insert into class_groups (study_program_id, class_type_id, code, name, entry_year, current_semester)
select sp.id, ct.id, 'TI-3A', 'TI 3A Reguler Pagi', 2023, 5
from study_programs sp, ref_class_types ct where sp.code='TI' and ct.code='REGULER';
insert into class_groups (study_program_id, class_type_id, code, name, entry_year, current_semester)
select sp.id, ct.id, 'TI-3M', 'TI 3 Reguler Malam', 2023, 5
from study_programs sp, ref_class_types ct where sp.code='TI' and ct.code='REGULER_MALAM';
insert into class_groups (study_program_id, class_type_id, code, name, entry_year, current_semester)
select sp.id, ct.id, 'TI-EXT-1', 'TI Ekstensi 1', 2023, 5
from study_programs sp, ref_class_types ct where sp.code='TI' and ct.code='EKSTENSI';

insert into locations (kind, code, name, latitude, longitude, radius_meters, is_geofenced)
values ('CAMPUS', 'KAMPUS-USM', 'Kampus Utama', -6.302, 106.652, 200, true);

insert into locations (parent_id, kind, code, name, building)
select id, 'BUILDING', 'GD-A', 'Gedung A', 'Gedung A' from locations where code='KAMPUS-USM';

insert into locations (parent_id, kind, code, name, building, floor, capacity)
select id, 'ROOM', 'GD-A-301', 'Lab Komputer 1', 'Gedung A', '3', 40 from locations where code='GD-A';
insert into locations (parent_id, kind, code, name, building, floor, capacity)
select id, 'ROOM', 'GD-A-302', 'Ruang Kelas 302', 'Gedung A', '3', 35 from locations where code='GD-A';

insert into courses (study_program_id, code, name, credits, semester)
select id, 'TI301', 'Pemrograman Mobile', 3, 5 from study_programs where code='TI';
insert into courses (study_program_id, code, name, credits, semester)
select id, 'TI302', 'Basis Data Lanjut', 3, 5 from study_programs where code='TI';
