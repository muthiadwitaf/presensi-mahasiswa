enum JenisAcademicEvent { liburNasional, kegiatanKampus }

class AcademicEvent {
  const AcademicEvent({required this.date, required this.title, required this.jenis});

  final DateTime date;
  final String title;
  final JenisAcademicEvent jenis;

  factory AcademicEvent.fromRow(Map<String, dynamic> row) {
    return AcademicEvent(
      date: DateTime.parse(row['event_date'] as String),
      title: row['title'] as String,
      jenis: row['event_type'] == 'KEGIATAN_KAMPUS' ? JenisAcademicEvent.kegiatanKampus : JenisAcademicEvent.liburNasional,
    );
  }
}
