import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/presensi_repository.dart';
import '../../core/utils/image_compression.dart';
import '../../models/izin_model.dart';
import '../../models/jadwal_model.dart';
import '../../models/presensi_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/jadwal_provider.dart';
import '../../widgets/empty_state.dart';
import 'kelola_jadwal_screen.dart';

class KelolaKelasScreen extends StatelessWidget {
  const KelolaKelasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Daftar Hadir'),
              Tab(text: 'Persetujuan Izin'),
              Tab(text: 'Kelola Jadwal'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DaftarHadirTab(),
                _PersetujuanIzinTab(),
                KelolaJadwalScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaftarHadirTab extends StatefulWidget {
  const _DaftarHadirTab();

  @override
  State<_DaftarHadirTab> createState() => _DaftarHadirTabState();
}

class _DaftarHadirTabState extends State<_DaftarHadirTab> {
  final _presensiRepo = PresensiRepository();
  JadwalModel? _selected;

  String _keteranganStatus(PresensiModel p) {
    if (p.statusAkhir == StatusAkhir.hadir) return 'Berhasil';
    if (!p.statusLiveness) return 'Gagal liveness';
    if (!p.statusFaceMatch) return 'Wajah tidak cocok';
    return p.alasanGagal ?? 'Ditolak';
  }

  @override
  Widget build(BuildContext context) {
    final jadwalList = context.watch<JadwalProvider>().jadwalList;
    _selected ??= jadwalList.isNotEmpty ? jadwalList.first : null;

    if (jadwalList.isEmpty) {
      return const EmptyState(message: 'Belum ada jadwal untuk ditampilkan', icon: Icons.class_outlined);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<JadwalModel>(
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Pilih Sesi'),
            items: jadwalList
                .map((j) => DropdownMenuItem(value: j, child: Text('${j.matkulNama} • ${j.hariLabel} ${j.jamMulai}')))
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PresensiModel>>(
            stream: _presensiRepo.watchByJadwal(_selected!.id),
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (list.isEmpty) {
                return const EmptyState(message: 'Belum ada mahasiswa presensi di sesi ini', icon: Icons.people_outline);
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final p = list[i];
                  final berhasil = p.statusAkhir == StatusAkhir.hadir;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        berhasil ? Icons.check_circle : Icons.cancel,
                        color: berhasil ? Colors.green : Colors.red,
                      ),
                      title: Text('${p.mahasiswaNama} (${p.mahasiswaNim})'),
                      subtitle: Text(
                        'Clock In ${DateFormat('HH:mm:ss').format(p.timestamp)}'
                        '${p.sudahClockOut ? ' • Clock Out ${DateFormat('HH:mm:ss').format(p.clockOutAt!)}' : ''}'
                        ' • ${_keteranganStatus(p)}'
                        '${p.livenessConfidence != null ? ' • conf ${(p.livenessConfidence! * 100).toStringAsFixed(0)}%' : ''}'
                        '${p.overrideBy != null ? ' • override dosen' : ''}',
                      ),
                      trailing: !berhasil
                          ? TextButton(
                              onPressed: () {
                                final dosenUid = context.read<AuthProvider>().currentUser!.uid;
                                _presensiRepo.overrideManual(presensiId: p.id, dosenUid: dosenUid);
                              },
                              child: const Text('Override'),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PersetujuanIzinTab extends StatelessWidget {
  const _PersetujuanIzinTab();

  @override
  Widget build(BuildContext context) {
    final izinProvider = context.watch<IzinProvider>();
    return StreamBuilder<List<IzinModel>>(
      stream: izinProvider.watchPending(),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (list.isEmpty) {
          return const EmptyState(message: 'Tidak ada pengajuan izin yang menunggu persetujuan', icon: Icons.mark_email_read_outlined);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final izin = list[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${izin.mahasiswaNama} (${izin.mahasiswaNim})', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${izin.matkulNama} • ${DateFormat('d MMM y', 'id_ID').format(izin.tanggal)}'),
                    const SizedBox(height: 6),
                    Text(izin.alasan),
                    if (izin.buktiBase64 != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          ImageCompression.decode(izin.buktiBase64!),
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.read<IzinProvider>().putuskan(izin.id, StatusIzin.ditolak),
                            child: const Text('Tolak'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => context.read<IzinProvider>().putuskan(izin.id, StatusIzin.disetujui),
                            child: const Text('Setujui'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
