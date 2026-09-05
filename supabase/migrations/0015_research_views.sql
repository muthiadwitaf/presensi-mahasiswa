-- Research/experiment metrics. RLS on the underlying attendance_verifications
-- table still applies to whoever queries these views (admin sees everything,
-- a lecturer/student sees only what their row-level policies already allow).

create view research_antispoof_confusion as
select experiment_tag,
       count(*) filter (where ground_truth_label='GENUINE' and anti_spoof_passed) as true_positive,
       count(*) filter (where ground_truth_label='SPOOF'   and anti_spoof_passed) as false_positive,
       count(*) filter (where ground_truth_label='SPOOF'   and not anti_spoof_passed) as true_negative,
       count(*) filter (where ground_truth_label='GENUINE' and not anti_spoof_passed) as false_negative
from attendance_verifications
where ground_truth_label in ('GENUINE','SPOOF')
group by experiment_tag;

create view research_face_similarity_distribution as
select experiment_tag,
       ground_truth_label,
       width_bucket(face_similarity, 0, 2, 20) as bucket,
       count(*) as n
from attendance_verifications
where ground_truth_label in ('GENUINE','IMPOSTOR') and face_similarity is not null
group by experiment_tag, ground_truth_label, bucket
order by experiment_tag, ground_truth_label, bucket;

create view research_failure_breakdown as
select course_class_id, failure_stage, outcome, count(*) as n
from attendance_verifications
where outcome <> 'PASS'
group by course_class_id, failure_stage, outcome;

grant select on research_antispoof_confusion, research_face_similarity_distribution, research_failure_breakdown
  to authenticated;

-- Non-biometric face-profile status for the profile screen: never exposes the embedding.
create or replace function app.my_face_profile_status()
returns table(has_profile boolean, enrolled_at timestamptz, updated_at timestamptz, quality_score real, version integer)
language sql stable security definer set search_path = '' as $$
  select true, fp.enrolled_at, fp.updated_at, fp.quality_score, fp.version
  from public.face_profiles fp
  where fp.student_id = app.current_student_id()
$$;
revoke execute on function app.my_face_profile_status() from public, anon;
grant execute on function app.my_face_profile_status() to authenticated;

-- Notification list, heavy targeting logic centralized here instead of a hot-path RLS query.
create or replace function app.my_notifications(p_limit integer default 30, p_offset integer default 0)
returns setof notifications
language sql stable security definer set search_path = '' as $$
  select n.* from public.notifications n
  where n.published_at <= now() and (n.expires_at is null or n.expires_at > now())
    and (
      (n.target_role is null and n.target_study_program_id is null and n.target_class_group_id is null and n.target_course_class_id is null)
      or n.target_role = app.current_role()
      or n.target_class_group_id = (select class_group_id from public.students where user_id = auth.uid())
      or n.target_study_program_id = (select study_program_id from public.students where user_id = auth.uid())
      or (n.target_course_class_id is not null and (app.is_enrolled(n.target_course_class_id) or app.teaches_class(n.target_course_class_id)))
      or exists (select 1 from public.notification_recipients nr where nr.notification_id = n.id and nr.user_id = auth.uid())
    )
  order by n.published_at desc
  limit p_limit offset p_offset
$$;
revoke execute on function app.my_notifications(integer, integer) from public, anon;
grant execute on function app.my_notifications(integer, integer) to authenticated;
