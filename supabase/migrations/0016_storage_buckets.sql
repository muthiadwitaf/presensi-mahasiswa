insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('face-photos', 'face-photos', false, 2097152, array['image/jpeg','image/png']),
  ('leave-attachments', 'leave-attachments', false, 2097152, array['image/jpeg','image/png','application/pdf']),
  ('avatars', 'avatars', false, 1048576, array['image/jpeg','image/png'])
on conflict (id) do nothing;

-- face-photos: no client INSERT/UPDATE (Edge Function enroll-face uploads via service role).
create policy face_photos_select_admin on storage.objects for select to authenticated
  using (bucket_id = 'face-photos' and app.is_admin());

-- leave-attachments: student uploads/reads their own; reviewing lecturer + admin can read.
create policy leave_attachments_insert_self on storage.objects for insert to authenticated
  with check (bucket_id = 'leave-attachments' and (storage.foldername(name))[1] = app.current_student_id()::text);
create policy leave_attachments_select_self on storage.objects for select to authenticated
  using (bucket_id = 'leave-attachments' and (storage.foldername(name))[1] = app.current_student_id()::text);
create policy leave_attachments_select_staff on storage.objects for select to authenticated
  using (bucket_id = 'leave-attachments' and (app.is_admin() or app.is_lecturer()));

-- avatars: user manages their own folder only.
create policy avatars_all_self on storage.objects for all to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
