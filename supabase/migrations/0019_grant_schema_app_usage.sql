-- Bug di schema sebelumnya: 0012_helper_functions.sql memberi EXECUTE pada
-- fungsi-fungsi app.* ke `authenticated`, tapi tidak pernah memberi USAGE
-- pada schema `app` itu sendiri. Tanpa USAGE, Postgres menolak akses
-- ("permission denied for schema app") sebelum sempat mengevaluasi hak
-- EXECUTE per fungsi - jadi SEMUA RLS policy yang memanggil app.is_admin(),
-- app.is_enrolled(), app.teaches_class(), dst (dipakai di hampir semua
-- tabel) gagal untuk role authenticated. Ditemukan lewat pengujian langsung
-- (signup + SELECT users/students sebagai user baru).
grant usage on schema app to authenticated;
