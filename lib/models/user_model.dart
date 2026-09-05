import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { mahasiswa, dosen, admin }

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.mahasiswa,
  );
}

class UserModel {
  final String uid;
  final String nim;
  final String nama;
  final UserRole role;

  /// Foto referensi wajah disimpan sebagai string Base64 langsung di
  /// dokumen Firestore (bukan Firebase Storage) - lihat catatan di
  /// `core/utils/image_compression.dart` untuk alasannya.
  final String? fotoWajahBase64;

  /// Embedding 192-d hasil MobileFaceNet dari foto referensi di atas -
  /// dipakai untuk pencocokan identitas wajah otomatis saat presensi
  /// (Opsi A). Lihat `core/services/face_embedding_service.dart` &
  /// `core/utils/face_matching.dart`.
  final List<double>? wajahEmbedding;
  final DateTime? fotoWajahUpdatedAt;

  const UserModel({
    required this.uid,
    required this.nim,
    required this.nama,
    required this.role,
    this.fotoWajahBase64,
    this.wajahEmbedding,
    this.fotoWajahUpdatedAt,
  });

  /// Baris dari tabel `public.users` di Supabase (lihat
  /// `core/services/supabase_auth_service.dart`). Field foto/embedding wajah
  /// TIDAK diisi lewat jalur ini - di arsitektur baru, embedding hidup di
  /// tabel `face_profiles` yang tidak boleh dibaca langsung oleh client
  /// (lihat RLS), jadi selalu null sampai fitur pendaftaran wajah (Fase
  /// 9-11) dipindah memakai Edge Function `enroll-face`.
  factory UserModel.fromSupabaseRow(Map<String, dynamic> map) {
    return UserModel(
      uid: map['id'] as String,
      nim: map['username'] as String? ?? '',
      nama: map['full_name'] as String? ?? '',
      role: userRoleFromString(map['role'] as String? ?? 'mahasiswa'),
    );
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      nim: map['nim'] as String? ?? '',
      nama: map['nama'] as String? ?? '',
      role: userRoleFromString(map['role'] as String? ?? 'mahasiswa'),
      fotoWajahBase64: map['fotoWajahBase64'] as String?,
      wajahEmbedding: (map['wajahEmbedding'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      fotoWajahUpdatedAt: (map['fotoWajahUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nim': nim,
      'nama': nama,
      'role': role.name,
      'fotoWajahBase64': fotoWajahBase64,
      'wajahEmbedding': wajahEmbedding,
      'fotoWajahUpdatedAt': fotoWajahUpdatedAt != null
          ? Timestamp.fromDate(fotoWajahUpdatedAt!)
          : null,
    };
  }

  UserModel copyWith({
    String? fotoWajahBase64,
    List<double>? wajahEmbedding,
    DateTime? fotoWajahUpdatedAt,
  }) {
    return UserModel(
      uid: uid,
      nim: nim,
      nama: nama,
      role: role,
      fotoWajahBase64: fotoWajahBase64 ?? this.fotoWajahBase64,
      wajahEmbedding: wajahEmbedding ?? this.wajahEmbedding,
      fotoWajahUpdatedAt: fotoWajahUpdatedAt ?? this.fotoWajahUpdatedAt,
    );
  }
}
