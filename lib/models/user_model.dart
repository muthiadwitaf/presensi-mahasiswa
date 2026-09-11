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

  const UserModel({
    required this.uid,
    required this.nim,
    required this.nama,
    required this.role,
  });

  factory UserModel.fromSupabaseRow(Map<String, dynamic> map) {
    return UserModel(
      uid: map['id'] as String,
      nim: map['username'] as String? ?? '',
      nama: map['full_name'] as String? ?? '',
      role: userRoleFromString(map['role'] as String? ?? 'mahasiswa'),
    );
  }
}
