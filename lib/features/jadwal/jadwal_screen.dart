import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/jadwal_model.dart';
import '../../providers/jadwal_provider.dart';
import '../../widgets/empty_state.dart';

class JadwalScreen extends StatelessWidget {
  const JadwalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JadwalProvider>();
    if (provider.jadwalList.isEmpty) {
      return const EmptyState(message: 'Belum ada jadwal mata kuliah', icon: Icons.calendar_month_outlined);
    }

    final Map<int, List<JadwalModel>> perHari = {};
    for (final j in provider.jadwalList) {
      perHari.putIfAbsent(j.hari, () => []).add(j);
    }
    final hariUrut = perHari.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final hari in hariUrut) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              JadwalModel.namaHari[hari] ?? '-',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...perHari[hari]!
              .map((j) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.book_outlined),
                      title: Text(j.matkulNama),
                      subtitle: Text('${j.jamMulai} - ${j.jamSelesai} • ${j.ruangNama}\nDosen: ${j.dosenNama}'),
                      isThreeLine: true,
                    ),
                  ))
              ,
        ],
      ],
    );
  }
}
