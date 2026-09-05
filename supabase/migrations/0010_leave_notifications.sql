-- Replaces `izin`.
create table leave_requests (
  id                 uuid primary key default gen_random_uuid(),
  student_id         uuid not null references students(id) on delete cascade,
  course_class_id    uuid references course_classes(id) on delete cascade,
  meeting_session_id uuid references meeting_sessions(id) on delete cascade,
  leave_type         leave_type not null default 'IZIN',
  date_from          date not null,
  date_to            date not null,
  reason             text not null,
  attachment_path    text,
  attachment_mime    text,
  status             leave_status not null default 'PENDING',
  reviewed_by        uuid references users(id),
  reviewed_at        timestamptz,
  review_note        text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint leave_range_chk check (date_to >= date_from),
  constraint leave_target_chk check (meeting_session_id is not null or course_class_id is not null)
);
create index leave_student_idx on leave_requests(student_id);
create index leave_status_idx  on leave_requests(status) where status = 'PENDING';
create index leave_session_idx on leave_requests(meeting_session_id);
create index leave_class_idx   on leave_requests(course_class_id);

alter table attendance_records add constraint attendance_leave_fk
  foreign key (leave_request_id) references leave_requests(id) on delete set null;

-- Approving an izin upserts the authoritative attendance_records row.
create or replace function app.leave_requests_apply_attendance() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_enrollment_id uuid; v_course_class_id uuid; v_status public.attendance_status;
begin
  if new.status = 'APPROVED' and new.meeting_session_id is not null
     and (old.status is distinct from 'APPROVED') then
    select course_class_id into v_course_class_id from public.meeting_sessions where id = new.meeting_session_id;
    select id into v_enrollment_id from public.enrollments
      where student_id = new.student_id and course_class_id = v_course_class_id and status = 'ACTIVE';
    v_status := case new.leave_type when 'SAKIT' then 'SAKIT'::public.attendance_status else 'IZIN'::public.attendance_status end;
    insert into public.attendance_records (student_id, meeting_session_id, enrollment_id, course_class_id,
      status, is_manual, overridden_by, overridden_at, override_reason, leave_request_id, verification_mode)
    values (new.student_id, new.meeting_session_id, v_enrollment_id, v_course_class_id,
      v_status, true, new.reviewed_by, now(), 'Izin/sakit disetujui', new.id, 'MANUAL_OVERRIDE')
    on conflict (student_id, meeting_session_id) do update set
      status = excluded.status, is_manual = true, overridden_by = excluded.overridden_by,
      overridden_at = now(), override_reason = excluded.override_reason,
      leave_request_id = excluded.leave_request_id, previous_status = attendance_records.status;
  end if;
  return new;
end $$;
create trigger leave_requests_apply_attendance_trg
  after update of status on leave_requests
  for each row execute function app.leave_requests_apply_attendance();

create table notifications (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  body           text not null,
  category       text not null default 'GENERAL'
                   check (category in ('GENERAL','SCHEDULE_CHANGE','ATTENDANCE','LEAVE','SYSTEM','ACADEMIC')),
  severity       text not null default 'INFO' check (severity in ('INFO','WARNING','CRITICAL')),
  action_type    text,
  action_payload jsonb,
  target_role              user_role,
  target_study_program_id  uuid references study_programs(id) on delete cascade,
  target_class_group_id    uuid references class_groups(id)   on delete cascade,
  target_course_class_id   uuid references course_classes(id) on delete cascade,
  created_by     uuid references users(id),
  created_by_name text,
  published_at   timestamptz not null default now(),
  expires_at     timestamptz,
  created_at     timestamptz not null default now()
);
create index notif_published_idx on notifications(published_at desc);
create index notif_target_idx    on notifications(target_role, target_class_group_id, target_course_class_id);

create table notification_recipients (
  id              uuid primary key default gen_random_uuid(),
  notification_id uuid not null references notifications(id) on delete cascade,
  user_id         uuid not null references users(id) on delete cascade,
  read_at         timestamptz,
  created_at      timestamptz not null default now(),
  unique (notification_id, user_id)
);
create index nr_user_unread_idx on notification_recipients(user_id) where read_at is null;
