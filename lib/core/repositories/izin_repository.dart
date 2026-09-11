import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/izin_model.dart';

class IzinRepository {
  IzinRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _selectWithJoins =
      '*, students(full_name, nim), course_classes(courses(name), academic_terms(code, academic_year, semester_type))';

  Future<String> _currentStudentId() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Belum login');
    final row = await _client.from('students').select('id').eq('user_id', uid).single();
    return row['id'] as String;
  }

  Future<void> ajukan({
    required String courseClassId,
    required JenisIzin jenis,
    required DateTime tanggal,
    required String alasan,
    File? bukti,
  }) async {
    final studentId = await _currentStudentId();
    String? attachmentPath;
    if (bukti != null) {
      final ext = bukti.path.contains('.') ? bukti.path.split('.').last : 'jpg';
      attachmentPath = '$studentId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from('leave-attachments').upload(attachmentPath, bukti);
    }
    await _client.from('leave_requests').insert({
      'student_id': studentId,
      'course_class_id': courseClassId,
      'leave_type': jenisIzinToDb(jenis),
      'date_from': _dateOnly(tanggal),
      'date_to': _dateOnly(tanggal),
      'reason': alasan,
      'attachment_path': ?attachmentPath,
    });
  }

  Future<List<IzinModel>> myLeaveRequests() async {
    final rows = await _client.from('leave_requests').select(_selectWithJoins).order('created_at', ascending: false);
    return (rows as List).map((r) => IzinModel.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<IzinModel>> pendingForLecturer() async {
    final rows = await _client
        .from('leave_requests')
        .select(_selectWithJoins)
        .eq('status', 'PENDING')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => IzinModel.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> putuskan(String izinId, StatusIzin status) {
    final uid = _client.auth.currentUser?.id;
    return _client.from('leave_requests').update({
      'status': statusIzinToDb(status),
      'reviewed_by': uid,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', izinId);
  }

  Future<String> attachmentSignedUrl(String path, {int expiresInSeconds = 3600}) {
    return _client.storage.from('leave-attachments').createSignedUrl(path, expiresInSeconds);
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
