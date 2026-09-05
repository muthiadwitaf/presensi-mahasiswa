import 'package:supabase_flutter/supabase_flutter.dart';

/// Opsi program studi untuk dropdown (registrasi, dsb). Representasi
/// minimal - model penuh `StudyProgram` menyusul di Fase 5/6 saat fitur
/// akademik lengkap dikerjakan.
class StudyProgramOption {
  const StudyProgramOption({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;

  factory StudyProgramOption.fromRow(Map<String, dynamic> row) {
    return StudyProgramOption(
      id: row['id'] as String,
      name: row['name'] as String,
      code: row['code'] as String,
    );
  }
}

/// Opsi kelas (class_group) untuk dropdown "Kelas yang Dikoordinasikan"
/// saat registrasi sebagai Koordinator Kelas.
class ClassGroupOption {
  const ClassGroupOption({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;

  factory ClassGroupOption.fromRow(Map<String, dynamic> row) {
    return ClassGroupOption(
      id: row['id'] as String,
      name: row['name'] as String,
      code: row['code'] as String,
    );
  }
}

/// Baca data referensi akademik (faktultas/prodi/kelas) yang boleh dibaca
/// publik (anon) - dipakai form registrasi sebelum pengguna login. Lihat
/// grant `anon` di `supabase/migrations/0018_self_registration_and_coordinator.sql`.
class AcademicReferenceRepository {
  AcademicReferenceRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<StudyProgramOption>> fetchStudyPrograms() async {
    final rows = await _client.from('study_programs').select('id, name, code').order('name');
    return (rows as List).map((r) => StudyProgramOption.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<ClassGroupOption>> fetchClassGroups() async {
    final rows = await _client.from('class_groups').select('id, name, code').order('name');
    return (rows as List).map((r) => ClassGroupOption.fromRow(r as Map<String, dynamic>)).toList();
  }
}
