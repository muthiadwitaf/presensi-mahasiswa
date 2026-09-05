create table audit_logs (
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references users(id) on delete set null,
  actor_role  user_role,
  action      text not null,
  entity_type text not null,
  entity_id   uuid,
  before_data jsonb,
  after_data  jsonb,
  ip_address  inet,
  user_agent  text,
  created_at  timestamptz not null default now()
);
create index audit_actor_idx  on audit_logs(actor_id);
create index audit_entity_idx on audit_logs(entity_type, entity_id);
create index audit_time_idx   on audit_logs(created_at desc);

create table device_bindings (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references users(id) on delete cascade,
  device_id_hash text not null,
  device_label   text,
  platform       text,
  first_seen_at  timestamptz not null default now(),
  last_seen_at   timestamptz not null default now(),
  is_trusted     boolean not null default false,
  is_blocked     boolean not null default false,
  unique (user_id, device_id_hash)
);

-- Pre-provisioned roster + self-activation: role is decided by admin, in the
-- DB, before the student ever signs up. The registration screen only asks
-- for username/activation code/password.
create table provisioned_accounts (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  full_name text not null,
  role user_role not null,
  study_program_id uuid references study_programs(id),
  class_group_id   uuid references class_groups(id),
  nim text,
  nip text,
  activation_code_hash text not null,
  expires_at timestamptz not null,
  claimed_at timestamptz,
  claimed_user_id uuid references users(id),
  created_by uuid references users(id),
  created_at timestamptz not null default now()
);
create unique index provisioned_accounts_username_unclaimed_idx
  on provisioned_accounts(username) where claimed_at is null;
