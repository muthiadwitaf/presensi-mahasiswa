create or replace function app.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_role public.user_role;
  v_pa record;
  v_username text;
  v_full_name text;
  v_self_role text;
  v_study_program_id uuid;
  v_class_group_id uuid;
  v_student_id uuid;
begin
  v_username := split_part(new.email, '@', 1);
  select * into v_pa from public.provisioned_accounts
   where username = v_username and claimed_at is null and expires_at > now();

  v_full_name := coalesce(new.raw_user_meta_data ->> 'full_name', v_pa.full_name, v_username);
  v_self_role := new.raw_user_meta_data ->> 'role';

  v_role := coalesce(
      nullif(new.raw_app_meta_data ->> 'role', '')::public.user_role,
      v_pa.role,

      case when v_self_role in ('mahasiswa', 'dosen', 'koordinator_kelas')
           then (case when v_self_role = 'koordinator_kelas' then 'mahasiswa' else v_self_role end)::public.user_role
      end);

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
    values (new.id, v_username, v_full_name, v_study_program_id, extract(year from now())::smallint)
    returning id into v_student_id;

    if v_self_role = 'koordinator_kelas' then
      v_class_group_id := nullif(new.raw_user_meta_data ->> 'class_group_id', '')::uuid;
      if v_class_group_id is null then
        raise exception 'Kelas yang dikoordinasikan wajib dipilih' using errcode = '23514';
      end if;
      insert into public.role_assignments (user_id, role, class_group_id, assigned_by)
      values (new.id, 'KOORDINATOR_KELAS', v_class_group_id, new.id);
    end if;
  elsif v_role = 'dosen' then
    v_study_program_id := nullif(new.raw_user_meta_data ->> 'study_program_id', '')::uuid;
    insert into public.lecturers (user_id, nip, full_name, study_program_id)
    values (new.id, v_username, v_full_name, v_study_program_id);
  end if;

  return new;
end $$;
