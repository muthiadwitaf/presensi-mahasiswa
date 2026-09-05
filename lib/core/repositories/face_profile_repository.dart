import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class FaceProfileStatus {
  const FaceProfileStatus({required this.hasProfile, this.enrolledAt, this.updatedAt, this.version, this.photoPath});

  final bool hasProfile;
  final DateTime? enrolledAt;
  final DateTime? updatedAt;
  final int? version;
  final String? photoPath;

  static const none = FaceProfileStatus(hasProfile: false);

  factory FaceProfileStatus.fromRow(Map<String, dynamic> row) {
    return FaceProfileStatus(
      hasProfile: row['has_profile'] as bool? ?? true,
      enrolledAt: row['enrolled_at'] != null ? DateTime.parse(row['enrolled_at'] as String) : null,
      updatedAt: row['updated_at'] != null ? DateTime.parse(row['updated_at'] as String) : null,
      version: (row['version'] as num?)?.toInt(),
      photoPath: row['photo_path'] as String?,
    );
  }
}

class EnrollFaceException implements Exception {
  const EnrollFaceException(this.code, this.message);
  final String code;
  final String message;

  String get userMessage => switch (code) {
        'QUALITY_TOO_LOW' => 'Kualitas foto kurang jelas, coba lagi dengan pencahayaan lebih baik',
        'COOLDOWN' => message,
        _ => message,
      };

  @override
  String toString() => 'EnrollFaceException($code: $message)';
}

/// Pendaftaran wajah lewat Edge Function `enroll-face` - client TIDAK
/// pernah menulis embedding langsung ke `face_profiles` (RLS tidak
/// memberi hak insert/update/select sama sekali ke mahasiswa, bahkan untuk
/// baris miliknya sendiri). Status baca lewat RPC `my_face_profile_status`
/// yang sengaja tidak mengembalikan embedding/foto.
///
/// CATATAN: tidak ada Edge Function untuk menghapus face profile sendiri -
/// backend saat ini cuma mendukung enroll (yang otomatis mengarsipkan versi
/// lama, lihat `face_profile_history`), bukan delete. Jangan tawarkan tombol
/// "hapus" di UI sampai kapabilitas itu ada.
class FaceProfileRepository {
  FaceProfileRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<FaceProfileStatus> status() async {
    final rows = await _client.rpc('my_face_profile_status') as List;
    if (rows.isEmpty) return FaceProfileStatus.none;
    return FaceProfileStatus.fromRow(rows.first as Map<String, dynamic>);
  }

  /// URL sementara (kedaluwarsa dalam [expiresInSeconds]) untuk preview foto
  /// wajah sendiri - bucket `face-photos` privat, jadi tidak bisa dipakai
  /// sebagai URL publik permanen.
  Future<String> photoSignedUrl(String photoPath, {int expiresInSeconds = 3600}) {
    return _client.storage.from('face-photos').createSignedUrl(photoPath, expiresInSeconds);
  }

  Future<void> enroll({
    required List<double> probeEmbedding,
    double? qualityScore,
    List<int>? photoBytes,
  }) async {
    final res = await _client.functions.invoke(
      'enroll-face',
      body: {
        'probe_embedding': probeEmbedding,
        'embedding_model': 'mobilefacenet-v1',
        'quality_score': ?qualityScore,
        'photo_base64': ?(photoBytes != null ? base64Encode(photoBytes) : null),
      },
    );
    final data = res.data;
    if (res.status != 200 || data is! Map || data['success'] != true) {
      final code = (data is Map ? data['code'] as String? : null) ?? 'ERROR';
      final message = (data is Map ? data['message'] as String? : null) ?? 'Pendaftaran wajah gagal (${res.status})';
      throw EnrollFaceException(code, message);
    }
  }
}
