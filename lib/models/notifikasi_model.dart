class NotifikasiModel {
  final String id;
  final String judul;
  final String isi;
  final String createdByNama;
  final DateTime createdAt;

  const NotifikasiModel({
    required this.id,
    required this.judul,
    required this.isi,
    required this.createdByNama,
    required this.createdAt,
  });

  factory NotifikasiModel.fromRow(Map<String, dynamic> row) {
    return NotifikasiModel(
      id: row['id'] as String,
      judul: row['title'] as String? ?? '',
      isi: row['body'] as String? ?? '',
      createdByNama: row['created_by_name'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
