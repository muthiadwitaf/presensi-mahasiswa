drop function if exists public.my_face_profile_status();
drop function if exists app.my_face_profile_status();

create or replace function app.my_face_profile_status()
returns table(has_profile boolean, enrolled_at timestamptz, updated_at timestamptz, quality_score real, version integer, photo_path text)
language sql stable security definer set search_path = '' as $$
  select true, fp.enrolled_at, fp.updated_at, fp.quality_score, fp.version, fp.photo_path
  from public.face_profiles fp
  where fp.student_id = app.current_student_id()
$$;
revoke execute on function app.my_face_profile_status() from public, anon;
grant execute on function app.my_face_profile_status() to authenticated;

create or replace function public.my_face_profile_status()
returns table(has_profile boolean, enrolled_at timestamptz, updated_at timestamptz, quality_score real, version integer, photo_path text)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_face_profile_status()
$$;
revoke execute on function public.my_face_profile_status() from public, anon;
grant execute on function public.my_face_profile_status() to authenticated;

drop policy if exists face_photos_select_self on storage.objects;
create policy face_photos_select_self on storage.objects for select to authenticated
  using (bucket_id = 'face-photos' and (storage.foldername(name))[1] = app.current_student_id()::text);
