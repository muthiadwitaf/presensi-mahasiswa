import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/session_today_model.dart';

class EnrolledCourseOption {
  const EnrolledCourseOption({required this.courseClassId, required this.courseCode, required this.courseName});
  final String courseClassId;
  final String courseCode;
  final String courseName;

  factory EnrolledCourseOption.fromRow(Map<String, dynamic> row) {
    return EnrolledCourseOption(
      courseClassId: row['course_class_id'] as String,
      courseCode: row['course_code'] as String? ?? '',
      courseName: row['course_name'] as String? ?? '',
    );
  }
}

/// Sumber kebenaran jadwal: `app.resolve_class_days` (jadwal template +
/// meeting session aktual) lewat RPC pembungkus di
/// `0021_today_sessions_helpers.sql`. Sengaja TIDAK ada cache lokal - dipanggil
/// ulang (mis. lewat `JadwalProvider.refresh()`) saat pengguna pull-to-refresh
/// atau timer periodik, bukan realtime stream seperti Firestore dulu.
class ScheduleRepository {
  ScheduleRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SessionToday>> sessionsForStudentOn(DateTime date) async {
    final rows = await _client.rpc('my_sessions_on', params: {'p_date': _dateOnly(date)});
    return (rows as List).map((r) => SessionToday.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<SessionToday>> sessionsForStudentBetween(DateTime from, DateTime to) async {
    final rows = await _client.rpc('my_sessions_between', params: {'p_from': _dateOnly(from), 'p_to': _dateOnly(to)});
    return (rows as List).map((r) => SessionToday.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<SessionToday>> sessionsForLecturerOn(DateTime date) async {
    final rows = await _client.rpc('my_taught_sessions_on', params: {'p_date': _dateOnly(date)});
    return (rows as List)
        .map((r) => SessionToday.fromRow({...r as Map<String, dynamic>, 'attendance_id': null, 'attendance_status': null}))
        .toList();
  }

  Future<List<EnrolledCourseOption>> myActiveCourseClasses() async {
    final rows = await _client.rpc('my_active_course_classes');
    return (rows as List).map((r) => EnrolledCourseOption.fromRow(r as Map<String, dynamic>)).toList();
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
