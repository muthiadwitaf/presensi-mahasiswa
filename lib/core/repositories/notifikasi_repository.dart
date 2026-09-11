import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/notifikasi_model.dart';

class TaughtCourseOption {
  const TaughtCourseOption({required this.courseClassId, required this.courseName});
  final String courseClassId;
  final String courseName;
}

class NotifikasiRepository {
  NotifikasiRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<NotifikasiModel>> myNotifications() async {
    final rows = await _client.from('notifications').select().order('published_at', ascending: false);
    return (rows as List).map((r) => NotifikasiModel.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<TaughtCourseOption>> myTaughtCourseClasses() async {
    final rows = await _client.from('course_classes').select('id, courses(name)');
    return (rows as List).map((r) {
      final map = r as Map<String, dynamic>;
      final course = map['courses'] as Map<String, dynamic>?;
      return TaughtCourseOption(courseClassId: map['id'] as String, courseName: course?['name'] as String? ?? '-');
    }).toList();
  }

  Future<void> buat({
    required String judul,
    required String isi,
    required String createdByNama,
    required String targetCourseClassId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('notifications').insert({
      'title': judul,
      'body': isi,
      'created_by': uid,
      'created_by_name': createdByNama,
      'target_course_class_id': targetCourseClassId,
    });
  }
}
