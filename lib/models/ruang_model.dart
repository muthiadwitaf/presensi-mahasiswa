/// Ruang kini murni informasi deskriptif (ditampilkan di Jadwal Kuliah) -
/// tidak lagi menyimpan koordinat/radius geofence, sesuai keputusan produk
/// untuk tidak lagi memvalidasi presensi terhadap batas lokasi ruang
/// tertentu (lihat `PresensiProvider` - lokasi tetap direkam sebagai log
/// saat Clock In, hanya tidak lagi jadi syarat lolos/gagal).
class RuangModel {
  final String id;
  final String nama;
  final String gedung;

  const RuangModel({
    required this.id,
    required this.nama,
    required this.gedung,
  });

  factory RuangModel.fromMap(String id, Map<String, dynamic> map) {
    return RuangModel(
      id: id,
      nama: map['nama'] as String? ?? '',
      gedung: map['gedung'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'gedung': gedung,
    };
  }

  String get label => '$nama ($gedung)';
}
