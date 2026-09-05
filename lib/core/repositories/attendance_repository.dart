import 'package:supabase_flutter/supabase_flutter.dart';

/// Hasil sukses `submit-attendance`.
class SubmitAttendanceResult {
  const SubmitAttendanceResult({
    required this.attendanceId,
    required this.status,
    required this.minutesLate,
  });
  final String attendanceId;
  final String status; // HADIR / TERLAMBAT
  final int minutesLate;
}

/// Kegagalan `submit-attendance` - `code` adalah salah satu FAIL_* dari Edge
/// Function (lihat submit-attendance/index.ts), TERMASUK "FAIL_RISK" yang
/// sengaja tidak ada di enum `verification_outcome` DB (dicatat sebagai
/// ERROR di server, tapi tetap dikembalikan sebagai kode ini ke client).
class SubmitAttendanceException implements Exception {
  const SubmitAttendanceException(this.code, this.message);
  final String code;
  final String message;

  /// Pesan berorientasi pengguna, bukan jargon teknis (lihat prinsip UI di
  /// spec: jangan tampilkan "FAIL_FACE_MATCH" mentah ke mahasiswa).
  String get userMessage => switch (code) {
        'FAIL_LIVENESS' => 'Verifikasi wajah gagal, pastikan pencahayaan cukup dan coba lagi',
        'FAIL_FACE_MATCH' => 'Wajah tidak cocok dengan data yang terdaftar',
        'FAIL_NO_FACE_PROFILE' => 'Anda belum mendaftarkan wajah',
        'FAIL_GEOFENCE' => 'Anda berada di luar lokasi yang ditentukan untuk sesi ini',
        'FAIL_WINDOW' => 'Sudah di luar jendela waktu presensi untuk sesi ini',
        'FAIL_SESSION_CLOSED' => 'Sesi ini sudah tidak menerima presensi',
        'FAIL_DUPLICATE' => 'Anda sudah melakukan presensi untuk sesi ini',
        'FAIL_NOT_ENROLLED' => 'Anda tidak terdaftar KRS untuk mata kuliah ini',
        'FAIL_MODE_MISMATCH' => 'Mode presensi tidak sesuai dengan mode sesi ini',
        'FAIL_RISK' => 'Presensi ditolak karena terdeteksi aktivitas mencurigakan',
        'FAIL_CHALLENGE' => 'Sesi verifikasi kedaluwarsa, silakan coba lagi',
        _ => message,
      };

  @override
  String toString() => 'SubmitAttendanceException($code: $message)';
}

/// Membungkus Edge Function `submit-attendance`/`submit-checkout` - client
/// HANYA mengirim evidence (embedding, skor liveness, lokasi), server yang
/// memutuskan status. Lihat catatan arsitektur di audit Fase 1 percakapan
/// ini - client tidak pernah menulis `status = HADIR` langsung ke DB.
class AttendanceRepository {
  AttendanceRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<SubmitAttendanceResult> submitAttendance({
    String? meetingSessionId,
    String? courseClassId,
    DateTime? sessionDate,
    required List<double> probeEmbedding,
    required double livenessScore,
    double? latitude,
    double? longitude,
    double? accuracyM,
    bool? isMocked,
    String? challengeNonce,
  }) async {
    final res = await _client.functions.invoke(
      'submit-attendance',
      body: {
        'meeting_session_id': ?meetingSessionId,
        'course_class_id': ?courseClassId,
        'session_date': ?(sessionDate != null ? _dateOnly(sessionDate) : null),
        'challenge_nonce': ?challengeNonce,
        'face': {'probe_embedding': probeEmbedding, 'embedding_model': 'mobilefacenet-v1'},
        'liveness': {'score': livenessScore, 'model': 'mobilenetv2-antispoof'},
        if (latitude != null && longitude != null)
          'location': {
            'latitude': latitude,
            'longitude': longitude,
            'accuracy_m': ?accuracyM,
            'is_mocked': ?isMocked,
          },
      },
    );

    final data = res.data;
    if (res.status != 200 || data is! Map || data['success'] != true) {
      final code = (data is Map ? data['code'] as String? : null) ?? 'ERROR';
      final message = (data is Map ? data['message'] as String? : null) ?? 'Presensi gagal (${res.status})';
      throw SubmitAttendanceException(code, message);
    }
    final attendance = data['attendance'] as Map;
    return SubmitAttendanceResult(
      attendanceId: attendance['id'] as String,
      status: attendance['status'] as String,
      minutesLate: (attendance['minutes_late'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> submitCheckout({required String attendanceId, double? latitude, double? longitude}) async {
    final res = await _client.functions.invoke(
      'submit-checkout',
      body: {
        'attendance_id': attendanceId,
        if (latitude != null && longitude != null) 'location': {'latitude': latitude, 'longitude': longitude},
      },
    );
    final data = res.data;
    if (res.status != 200 || data is! Map || data['success'] != true) {
      final message = (data is Map ? data['message'] as String? : null) ?? 'Clock out gagal (${res.status})';
      throw StateError(message);
    }
  }

  /// Daftar hadir untuk satu meeting session (dipakai dosen di tab "Daftar
  /// Hadir") - RLS `attendance_records` sudah membatasi ke sesi yang
  /// memang diampu dosen tsb.
  Future<List<Map<String, dynamic>>> attendeesForSession(String meetingSessionId) async {
    final rows = await _client
        .from('attendance_records')
        .select('id, status, check_in_at, check_out_at, face_similarity, anti_spoof_score, is_manual, students(full_name, nim)')
        .eq('meeting_session_id', meetingSessionId)
        .order('check_in_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Riwayat presensi mahasiswa sendiri - RLS `attendance_records` sudah
  /// membatasi ke baris milik sendiri, tidak perlu filter student_id manual.
  Future<List<Map<String, dynamic>>> myAttendanceHistory({int limit = 200}) async {
    final rows = await _client
        .from('attendance_records')
        .select('id, status, check_in_at, check_out_at, course_class_id, course_classes(courses(name))')
        .order('check_in_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
