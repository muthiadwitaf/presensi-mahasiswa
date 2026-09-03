/// hari: 1 = Senin ... 7 = Minggu (mengikuti DateTime.weekday)
class JadwalModel {
  final String id;
  final String matkulId;
  final String matkulNama;
  final String dosenNama;
  final String ruangId;
  final String ruangNama;
  final int hari;
  final String jamMulai; // format "HH:mm"
  final String jamSelesai; // format "HH:mm"

  const JadwalModel({
    required this.id,
    required this.matkulId,
    required this.matkulNama,
    required this.dosenNama,
    required this.ruangId,
    required this.ruangNama,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
  });

  factory JadwalModel.fromMap(String id, Map<String, dynamic> map) {
    return JadwalModel(
      id: id,
      matkulId: map['matkulId'] as String? ?? '',
      matkulNama: map['matkulNama'] as String? ?? '',
      dosenNama: map['dosenNama'] as String? ?? '',
      ruangId: map['ruangId'] as String? ?? '',
      ruangNama: map['ruangNama'] as String? ?? '',
      hari: (map['hari'] as num?)?.toInt() ?? 1,
      jamMulai: map['jamMulai'] as String? ?? '00:00',
      jamSelesai: map['jamSelesai'] as String? ?? '00:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matkulId': matkulId,
      'matkulNama': matkulNama,
      'dosenNama': dosenNama,
      'ruangId': ruangId,
      'ruangNama': ruangNama,
      'hari': hari,
      'jamMulai': jamMulai,
      'jamSelesai': jamSelesai,
    };
  }

  static const namaHari = <int, String>{
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
    7: 'Minggu',
  };

  String get hariLabel => namaHari[hari] ?? '-';

  DateTime _timeToday(String hhmm, DateTime now) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(now.year, now.month, now.day, h, m);
  }

  /// Apakah [now] berada dalam jendela waktu sesi ini (hari & jam cocok).
  bool isActiveAt(DateTime now) {
    if (now.weekday != hari) return false;
    final mulai = _timeToday(jamMulai, now);
    final selesai = _timeToday(jamSelesai, now);
    return !now.isBefore(mulai) && now.isBefore(selesai);
  }

  /// Apakah sesi ini akan berlangsung hari ini tapi belum mulai.
  bool isUpcomingToday(DateTime now) {
    if (now.weekday != hari) return false;
    final mulai = _timeToday(jamMulai, now);
    return now.isBefore(mulai);
  }
}
