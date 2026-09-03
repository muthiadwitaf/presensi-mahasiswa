import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/presensi_repository.dart';
import '../../models/presensi_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';

class _RekapMatkul {
  int hadir = 0;
  int total = 0;
  double get persentase => total == 0 ? 0 : hadir / total * 100;
}

class RekapScreen extends StatelessWidget {
  RekapScreen({super.key});

  final _repo = PresensiRepository();

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<PresensiModel>>(
      stream: _repo.watchByMahasiswa(uid),
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
          final r = perMatkul.putIfAbsent(log.matkulNama, () => _RekapMatkul());
          r.total++;
          if (log.statusAkhir == StatusAkhir.hadir) r.hadir++;
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
            ...logs.take(10).map((log) => Card(
                  child: ListTile(
                    leading: Icon(
                      log.statusAkhir == StatusAkhir.hadir ? Icons.check_circle : Icons.cancel,
                      color: log.statusAkhir == StatusAkhir.hadir ? Colors.green : Colors.red,
                    ),
                    title: Text(log.matkulNama),
                    subtitle: Text(DateFormat('EEEE, d MMM y • HH:mm', 'id_ID').format(log.timestamp)),
                  ),
                )),
          ],
        );
      },
    );
  }
}
