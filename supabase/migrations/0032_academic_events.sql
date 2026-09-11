create table academic_events (
  id uuid primary key default gen_random_uuid(),
  event_date date not null,
  title text not null,
  event_type text not null check (event_type in ('LIBUR_NASIONAL', 'KEGIATAN_KAMPUS')),
  created_at timestamptz not null default now(),
  unique (event_date, title)
);
create index academic_events_date_idx on academic_events(event_date);

alter table academic_events enable row level security;
grant select on academic_events to authenticated;
create policy academic_events_select_all on academic_events for select to authenticated using (true);

insert into academic_events (event_date, title, event_type) values
  ('2026-01-01', 'Tahun Baru Masehi', 'LIBUR_NASIONAL'),
  ('2026-02-17', 'Tahun Baru Imlek 2577', 'LIBUR_NASIONAL'),
  ('2026-03-19', 'Hari Suci Nyepi (Tahun Baru Saka 1948)', 'LIBUR_NASIONAL'),
  ('2026-03-20', 'Hari Raya Idul Fitri 1447 H', 'LIBUR_NASIONAL'),
  ('2026-03-21', 'Hari Raya Idul Fitri 1447 H', 'LIBUR_NASIONAL'),
  ('2026-04-03', 'Wafat Isa Almasih', 'LIBUR_NASIONAL'),
  ('2026-05-01', 'Hari Buruh Internasional', 'LIBUR_NASIONAL'),
  ('2026-05-14', 'Kenaikan Isa Almasih', 'LIBUR_NASIONAL'),
  ('2026-05-27', 'Hari Raya Idul Adha 1447 H', 'LIBUR_NASIONAL'),
  ('2026-05-31', 'Hari Raya Waisak', 'LIBUR_NASIONAL'),
  ('2026-06-01', 'Hari Lahir Pancasila', 'LIBUR_NASIONAL'),
  ('2026-06-16', 'Tahun Baru Islam 1448 H', 'LIBUR_NASIONAL'),
  ('2026-08-17', 'Hari Kemerdekaan Republik Indonesia', 'LIBUR_NASIONAL'),
  ('2026-08-25', 'Maulid Nabi Muhammad SAW', 'LIBUR_NASIONAL'),
  ('2026-12-25', 'Hari Raya Natal', 'LIBUR_NASIONAL')
on conflict (event_date, title) do nothing;
