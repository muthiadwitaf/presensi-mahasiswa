import 'package:supabase_flutter/supabase_flutter.dart';

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
