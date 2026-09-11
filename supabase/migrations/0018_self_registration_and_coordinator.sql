grant select on faculties, study_programs, class_groups to anon;
drop policy if exists faculties_select_anon on faculties;
create policy faculties_select_anon on faculties for select to anon using (true);
drop policy if exists study_programs_select_anon on study_programs;
create policy study_programs_select_anon on study_programs for select to anon using (true);
drop policy if exists class_groups_select_anon on class_groups;
create policy class_groups_select_anon on class_groups for select to anon using (true);

create table if not exists role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  role text not null check (role in ('KOORDINATOR_KELAS')),
  class_group_id uuid not null references class_groups(id) on delete cascade,
  assigned_by uuid references users(id),
  assigned_at timestamptz not null default now(),
  unique (user_id, role, class_group_id)
);

create index if not exists role_assignments_user_id_idx on role_assignments(user_id);
create index if not exists role_assignments_class_group_id_idx on role_assignments(class_group_id);

alter table role_assignments enable row level security;
alter table role_assignments force row level security;
revoke all on role_assignments from authenticated, anon;
grant select on role_assignments to authenticated;

drop policy if exists role_assignments_select_self on role_assignments;
create policy role_assignments_select_self on role_assignments for select to authenticated
  using (user_id = auth.uid() or app.is_admin());

drop policy if exists role_assignments_write_admin on role_assignments;
create policy role_assignments_write_admin on role_assignments for all to authenticated
  using (app.is_admin()) with check (app.is_admin());

create or replace function app.is_coordinator_of(p_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.role_assignments
    where user_id = auth.uid()
      and role = 'KOORDINATOR_KELAS'
      and class_group_id = p_class_group_id
  );
$$;

create or replace function app.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_role public.user_role;
  v_pa record;
  v_username text;
  v_full_name text;
  v_self_role text;
  v_study_program_id uuid;
begin
  v_username := split_part(new.email, '@', 1);
  select * into v_pa from public.provisioned_accounts
   where username = v_username and claimed_at is null and expires_at > now();

  v_full_name := coalesce(new.raw_user_meta_data ->> 'full_name', v_pa.full_name, v_username);
  v_self_role := new.raw_user_meta_data ->> 'role';

  v_role := coalesce(
      nullif(new.raw_app_meta_data ->> 'role', '')::public.user_role,
      v_pa.role,
      case when v_self_role in ('mahasiswa', 'dosen') then v_self_role::public.user_role end);

  if v_role is null then
    raise exception 'Akun tidak ter-provisioning dan peran tidak valid. Hubungi admin.' using errcode = '42501';
  end if;

  insert into public.users (id, username, full_name, role, status, created_by)
  values (new.id, v_username, v_full_name, v_role, 'active', v_pa.created_by);

  if v_pa.id is not null then
    update public.provisioned_accounts
      set claimed_at = now(), claimed_user_id = new.id
      where id = v_pa.id;
  elsif v_role = 'mahasiswa' then
    v_study_program_id := nullif(new.raw_user_meta_data ->> 'study_program_id', '')::uuid;
    if v_study_program_id is null then
      raise exception 'Program studi wajib diisi saat mendaftar' using errcode = '23514';
    end if;
    insert into public.students (user_id, nim, full_name, study_program_id, entry_year)
    values (new.id, v_username, v_full_name, v_study_program_id, extract(year from now())::smallint);
  elsif v_role = 'dosen' then
    v_study_program_id := nullif(new.raw_user_meta_data ->> 'study_program_id', '')::uuid;
    insert into public.lecturers (user_id, nip, full_name, study_program_id)
    values (new.id, v_username, v_full_name, v_study_program_id);
  end if;

  return new;
end $$;
