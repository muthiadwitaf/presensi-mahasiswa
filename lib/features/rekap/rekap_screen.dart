import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/attendance_repository.dart';
import '../../widgets/empty_state.dart';

class _RekapMatkul {
  int hadir = 0;
  int total = 0;
  double get persentase => total == 0 ? 0 : hadir / total * 100;
}

class RekapScreen extends StatefulWidget {
  const RekapScreen({super.key});

  @override
  State<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends State<RekapScreen> {
  final _repo = AttendanceRepository();
  late final Future<List<Map<String, dynamic>>> _future = _repo.myAttendanceHistory();

  static String _courseName(Map<String, dynamic> log) {
    final courseClass = log['course_classes'] as Map<String, dynamic>?;
    final course = courseClass?['courses'] as Map<String, dynamic>?;
    return course?['name'] as String? ?? '-';
  }

  static bool _hadir(Map<String, dynamic> log) {
    final status = log['status'] as String?;
    return status == 'HADIR' || status == 'TERLAMBAT';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data!;
        if (logs.isEmpty) {
          return const EmptyState(
            message: 'Belum ada riwayat presensi',
            icon: Icons.fact_check_outlined,
          );
        }

        final Map<String, _RekapMatkul> perMatkul = {};
        for (final log in logs) {
          final r = perMatkul.putIfAbsent(_courseName(log), () => _RekapMatkul());
          r.total++;
          if (_hadir(log)) r.hadir++;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Persentase dihitung dari log presensi yang tercatat (bukan dari kalender akademik lengkap).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ...perMatkul.entries.map((e) {
              final memenuhiSyarat = e.value.persentase >= 75;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: e.value.persentase / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: memenuhiSyarat ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${e.value.persentase.toStringAsFixed(1)}% hadir (${e.value.hadir}/${e.value.total}) '
                        '${memenuhiSyarat ? '' : '- di bawah syarat minimal 75% UAS'}',
                        style: TextStyle(fontSize: 12.5, color: memenuhiSyarat ? Colors.green.shade700 : Colors.orange.shade800),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            Text('Riwayat Terbaru', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...logs.take(10).map((log) {
              final berhasil = _hadir(log);
              final checkIn = log['check_in_at'] != null ? DateTime.parse(log['check_in_at'] as String) : null;
              return Card(
                child: ListTile(
                  leading: Icon(
                    berhasil ? Icons.check_circle : Icons.cancel,
                    color: berhasil ? Colors.green : Colors.red,
                  ),
                  title: Text(_courseName(log)),
                  subtitle: Text(checkIn != null ? DateFormat('EEEE, d MMM y • HH:mm', 'id_ID').format(checkIn) : '-'),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
