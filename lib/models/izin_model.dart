enum StatusIzin { pending, disetujui, ditolak, dibatalkan }

StatusIzin statusIzinFromDb(String value) {
  return switch (value) {
    'APPROVED' => StatusIzin.disetujui,
    'REJECTED' => StatusIzin.ditolak,
    'CANCELLED' => StatusIzin.dibatalkan,
    _ => StatusIzin.pending,
  };
}

String statusIzinToDb(StatusIzin status) {
  return switch (status) {
    StatusIzin.pending => 'PENDING',
    StatusIzin.disetujui => 'APPROVED',
    StatusIzin.ditolak => 'REJECTED',
    StatusIzin.dibatalkan => 'CANCELLED',
  };
}

enum JenisIzin { izin, sakit }

JenisIzin jenisIzinFromDb(String? value) => value == 'SAKIT' ? JenisIzin.sakit : JenisIzin.izin;
String jenisIzinToDb(JenisIzin jenis) => jenis == JenisIzin.sakit ? 'SAKIT' : 'IZIN';

class IzinModel {
  final String id;
  final String studentId;
  final String mahasiswaNama;
  final String mahasiswaNim;
  final String? courseClassId;
  final String matkulNama;
  final String semesterLabel;
  final JenisIzin jenis;
  final DateTime tanggal;
  final String alasan;
  final String? attachmentPath;
  final StatusIzin status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  const IzinModel({
    required this.id,
    required this.studentId,
    required this.mahasiswaNama,
    required this.mahasiswaNim,
    this.courseClassId,
    required this.matkulNama,
    required this.semesterLabel,
    required this.jenis,
    required this.tanggal,
    required this.alasan,
    this.attachmentPath,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewNote,
  });

  factory IzinModel.fromRow(Map<String, dynamic> row) {
    final student = row['students'] as Map<String, dynamic>?;
    final courseClass = row['course_classes'] as Map<String, dynamic>?;
    final course = courseClass?['courses'] as Map<String, dynamic>?;
    final term = courseClass?['academic_terms'] as Map<String, dynamic>?;
    final semesterLabel = term != null
        ? '${term['academic_year']} ${term['semester_type'] == 'GENAP' ? 'Genap' : 'Ganjil'}'
        : 'Semester lain';
    return IzinModel(
      id: row['id'] as String,
      studentId: row['student_id'] as String,
      mahasiswaNama: student?['full_name'] as String? ?? '',
      mahasiswaNim: student?['nim'] as String? ?? '',
      courseClassId: row['course_class_id'] as String?,
      matkulNama: course?['name'] as String? ?? '',
      semesterLabel: semesterLabel,
      jenis: jenisIzinFromDb(row['leave_type'] as String?),
      tanggal: DateTime.parse(row['date_from'] as String),
      alasan: row['reason'] as String? ?? '',
      attachmentPath: row['attachment_path'] as String?,
      status: statusIzinFromDb(row['status'] as String? ?? 'PENDING'),
      createdAt: DateTime.parse(row['created_at'] as String),
      reviewedAt: row['reviewed_at'] != null ? DateTime.parse(row['reviewed_at'] as String) : null,
      reviewNote: row['review_note'] as String?,
    );
  }
}
