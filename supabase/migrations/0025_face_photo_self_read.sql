-- Izinkan mahasiswa melihat foto wajahnya SENDIRI yang sudah terdaftar
-- (untuk preview di layar "Wajah Terdaftar") - sebelumnya sengaja
-- diblokir total. Pola storage policy-nya mengikuti leave-attachments
-- (self-read berdasarkan folder = milik sendiri), bukan admin-only lagi
-- khusus utk bucket face-photos.

create policy face_photos_select_self on storage.objects for select to authenticated
  using (bucket_id = 'face-photos' and (storage.foldername(name))[1] = app.current_student_id()::text);

-- my_face_profile_status sekarang juga mengembalikan photo_path (path di
-- bucket face-photos) - TETAP TIDAK mengembalikan embedding.
create or replace function app.my_face_profile_status()
returns table(has_profile boolean, enrolled_at timestamptz, updated_at timestamptz, quality_score real, version integer, photo_path text)
language sql stable security definer set search_path = '' as $$
  select true, fp.enrolled_at, fp.updated_at, fp.quality_score, fp.version, fp.photo_path
  from public.face_profiles fp
  where fp.student_id = app.current_student_id()
$$;

create or replace function public.my_face_profile_status()
returns table(has_profile boolean, enrolled_at timestamptz, updated_at timestamptz, quality_score real, version integer, photo_path text)
language sql stable security invoker set search_path = '' as $$
  select * from app.my_face_profile_status()
$$;
