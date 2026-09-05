import 'package:flutter/material.dart';

import '../../core/repositories/schedule_repository.dart';
import '../../models/session_today_model.dart';
import '../../widgets/empty_state.dart';

const _namaHari = <int, String>{
  1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Minggu',
};

/// Jadwal 7 hari ke depan, sumber kebenaran `resolve_class_days` (jadwal
/// template + meeting session aktual - lihat migration
/// `0008_schedules_sessions.sql`) sehingga otomatis mencerminkan sesi yang
/// dipindah/dibatalkan dosen, bukan jadwal statis mingguan seperti dulu.
class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  final _repo = ScheduleRepository();
  late Future<List<SessionToday>> _future;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  void _muat() {
    final now = DateTime.now();
    _future = _repo.sessionsForStudentBetween(now, now.add(const Duration(days: 6)));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(_muat),
      child: FutureBuilder<List<SessionToday>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sesiList = snapshot.data!;
          if (sesiList.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(message: 'Belum ada jadwal mata kuliah', icon: Icons.calendar_month_outlined),
              ],
            );
          }

          final Map<String, List<SessionToday>> perHari = {};
          for (final s in sesiList) {
            final tanggal = s.sessionDate;
            final label = tanggal != null
                ? '${_namaHari[tanggal.weekday] ?? '-'}, ${tanggal.day}/${tanggal.month}'
                : '-';
            perHari.putIfAbsent(label, () => []).add(s);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in perHari.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ...entry.value.map((s) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.book_outlined),
                        title: Text(s.courseName),
                        subtitle: Text(
                          '${s.startTimeLabel} - ${s.endTimeLabel} • '
                          '${s.mode == 'ONLINE' ? 'Online' : s.locationName ?? 'Offline'}'
                          '${s.lecturerName != null ? '\nDosen: ${s.lecturerName}' : ''}'
                          '${s.sessionStatus == 'RESCHEDULED' ? '\nJadwal berubah dari sesi reguler' : ''}'
                          '${s.isCancelled ? '\nSesi ini dibatalkan' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: s.isCancelled
                            ? const Chip(label: Text('Batal', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFFFDE2E2))
                            : null,
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}
