import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/attendance_repository.dart';
import '../../core/utils/image_compression.dart';
import '../../models/izin_model.dart';
import '../../models/session_today_model.dart';
import '../../providers/izin_provider.dart';
import '../../providers/jadwal_provider.dart';
import '../../widgets/empty_state.dart';

/// "Kelola Jadwal" (CRUD matkul/ruang/jadwal manual) sudah dihapus dari
/// mobile - sesuai keputusan migrasi, administrasi akademik (termasuk
/// jadwal) sekarang wewenang Web Admin terpisah, bukan aplikasi dosen.
class KelolaKelasScreen extends StatelessWidget {
  const KelolaKelasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Daftar Hadir'),
              Tab(text: 'Persetujuan Izin'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DaftarHadirTab(),
                _PersetujuanIzinTab(),
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
  final _attendanceRepo = AttendanceRepository();
  SessionToday? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<JadwalProvider>().refreshDosen());
  }

  @override
  Widget build(BuildContext context) {
    final sesiList = context.watch<JadwalProvider>().sesiDosenHariIni;
    if (_selected == null || !sesiList.contains(_selected)) {
      _selected = sesiList.isNotEmpty ? sesiList.first : null;
    }

    if (sesiList.isEmpty) {
      return const EmptyState(message: 'Tidak ada kelas yang Anda ampu hari ini', icon: Icons.class_outlined);
    }

    final sesi = _selected!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<SessionToday>(
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Pilih Sesi'),
            items: sesiList
                .map((s) => DropdownMenuItem(value: s, child: Text('${s.courseName} • ${s.startTimeLabel}')))
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
          ),
        ),
        Expanded(
          child: sesi.meetingSessionId == null
              ? const EmptyState(message: 'Sesi ini belum dimulai/dibuat', icon: Icons.hourglass_empty)
              : FutureBuilder<List<Map<String, dynamic>>>(
                  future: _attendanceRepo.attendeesForSession(sesi.meetingSessionId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final list = snapshot.data!;
                    if (list.isEmpty) {
                      return const EmptyState(message: 'Belum ada mahasiswa presensi di sesi ini', icon: Icons.people_outline);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final a = list[i];
                        final student = a['students'] as Map?;
                        final berhasil = a['status'] == 'HADIR' || a['status'] == 'TERLAMBAT';
                        final checkIn = a['check_in_at'] != null ? DateTime.parse(a['check_in_at'] as String) : null;
                        final checkOut = a['check_out_at'] != null ? DateTime.parse(a['check_out_at'] as String) : null;
                        final faceSim = a['face_similarity'] as num?;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              berhasil ? Icons.check_circle : Icons.cancel,
                              color: berhasil ? Colors.green : Colors.red,
                            ),
                            title: Text('${student?['full_name'] ?? '-'} (${student?['nim'] ?? '-'})'),
                            subtitle: Text(
                              '${a['status']}'
                              '${checkIn != null ? ' • Masuk ${DateFormat('HH:mm:ss').format(checkIn)}' : ''}'
                              '${checkOut != null ? ' • Keluar ${DateFormat('HH:mm:ss').format(checkOut)}' : ''}'
                              '${faceSim != null ? ' • similarity ${(faceSim * 100).toStringAsFixed(0)}%' : ''}'
                              '${a['is_manual'] == true ? ' • override dosen' : ''}',
                            ),
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
