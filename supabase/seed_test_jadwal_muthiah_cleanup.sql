delete from attendance_records ar
using meeting_sessions ms, course_classes cc
where ar.meeting_session_id = ms.id and ms.course_class_id = cc.id
  and cc.code like '%-TEST';

delete from meeting_sessions ms
using course_classes cc
where ms.course_class_id = cc.id and cc.code like '%-TEST';

delete from enrollments e
using course_classes cc
where e.course_class_id = cc.id and cc.code like '%-TEST';

delete from schedules s
using course_classes cc
where s.course_class_id = cc.id and cc.code like '%-TEST';

delete from course_classes where code like '%-TEST';
delete from courses where code like '%-TEST';
delete from academic_terms where code = '2025/2026-GENAP'
  and not exists (select 1 from course_classes where academic_term_id = academic_terms.id);
