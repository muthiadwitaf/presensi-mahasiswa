import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/presensi_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../models/jadwal_model.dart';
import '../../models/presensi_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jadwal_provider.dart';
import '../../providers/presensi_provider.dart';
import '../../widgets/empty_state.dart';
import '../presensi/presensi_flow_screen.dart';
import '../wajah/wajah_terdaftar_screen.dart';
import 'widgets/session_status_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _ticker;
  final _presensiRepo = PresensiRepository();

  @override
  void initState() {
    super.initState();
    // Jendela waktu sesi aktif bergantung pada jam berjalan, bukan cuma
    // perubahan data Firestore - refresh berkala supaya status tetap akurat.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _bukaPresensi(JadwalModel sesi) async {
    final mahasiswa = context.read<AuthProvider>().currentUser!;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresensiFlowScreen(sesi: sesi, mahasiswa: mahasiswa),
      ),
    );
    if (mounted) context.read<PresensiProvider>().resetUntukSesiBaru();
  }

  Future<void> _clockOut(PresensiModel presensi) async {
    final provider = context.read<PresensiProvider>();
    final ok = await provider.clockOut(presensi);
    if (!ok && mounted && provider.clockOutError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.clockOutError!)));
    }
  }

  void _bukaDaftarWajah() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Wajah Terdaftar')),
          body: const WajahTerdaftarScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final jadwalProvider = context.watch<JadwalProvider>();
    final sesiHariIni = user.role == UserRole.dosen
        ? jadwalProvider.sesiHariIni().where((j) => j.dosenNama == user.nama).toList()
        : jadwalProvider.sesiHariIni();

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Greeting(nama: user.nama),
          const SizedBox(height: 16),
          if (user.role == UserRole.mahasiswa) ...[
            _buildPresensiCard(context, jadwalProvider, user),
            const SizedBox(height: 16),
            _KehadiranSemesterCard(mahasiswaUid: user.uid, repo: _presensiRepo),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text('Jadwal Hari Ini', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (sesiHariIni.isEmpty)
            const EmptyState(message: 'Tidak ada jadwal mata kuliah hari ini', icon: Icons.event_busy)
          else
            ...sesiHariIni.map((j) => _JadwalHariIniCard(
                  jadwal: j,
                  mahasiswaUid: user.role == UserRole.mahasiswa ? user.uid : null,
                  repo: _presensiRepo,
                )),
        ],
      ),
    );
  }

  Widget _buildPresensiCard(BuildContext context, JadwalProvider jadwalProvider, UserModel mahasiswa) {
    final presensiProvider = context.watch<PresensiProvider>();
    final sesi = jadwalProvider.sesiAktifSekarang();

    if (sesi == null) {
      return SessionStatusCard(
        sesi: null,
        presensi: presensiProvider,
        wajahTerdaftar: mahasiswa.wajahEmbedding != null,
        presensiHariIni: null,
        onMulaiPresensi: () {},
        onDaftarWajah: _bukaDaftarWajah,
        onClockOut: () {},
      );
    }

    return StreamBuilder<PresensiModel?>(
      stream: _presensiRepo.watchPresensiHariIni(mahasiswaUid: mahasiswa.uid, jadwalId: sesi.id),
      builder: (context, snapshot) {
        return SessionStatusCard(
          sesi: sesi,
          presensi: presensiProvider,
          wajahTerdaftar: mahasiswa.wajahEmbedding != null,
          presensiHariIni: snapshot.data,
          onMulaiPresensi: () => _bukaPresensi(sesi),
          onDaftarWajah: _bukaDaftarWajah,
          onClockOut: () => _clockOut(snapshot.data!),
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.nama});
  final String nama;

  String get _sapaan {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(gradient: AppTheme.brandGradient, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_sapaan, $nama', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const Text('Sistem Presensi Mahasiswa', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _KehadiranSemesterCard extends StatelessWidget {
  const _KehadiranSemesterCard({required this.mahasiswaUid, required this.repo});
  final String mahasiswaUid;
  final PresensiRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PresensiModel>>(
      stream: repo.watchByMahasiswa(mahasiswaUid),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        final hadir = logs.where((l) => l.statusAkhir == StatusAkhir.hadir).length;
        final total = logs.length;
        final persen = total == 0 ? 0.0 : hadir / total * 100;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kehadiran Semester', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 10),
                Text(
                  total == 0 ? '-' : '${persen.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.primary),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : persen / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    color: persen >= 75 ? AppTheme.success : AppTheme.warning,
                  ),
                ),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$hadir dari $total sesi tercatat',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JadwalHariIniCard extends StatelessWidget {
  const _JadwalHariIniCard({required this.jadwal, required this.mahasiswaUid, required this.repo});

  final JadwalModel jadwal;
  final String? mahasiswaUid;
  final PresensiRepository repo;

  @override
  Widget build(BuildContext context) {
    final uid = mahasiswaUid;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule, color: AppTheme.textSecondary),
        title: Text(jadwal.matkulNama, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${jadwal.jamMulai} - ${jadwal.jamSelesai} • ${jadwal.ruangNama} • ${jadwal.dosenNama}'),
        trailing: uid == null
            ? (jadwal.isActiveAt(DateTime.now())
                ? const Chip(label: Text('Aktif'), backgroundColor: Color(0xFFDFF5E1))
                : null)
            : StreamBuilder<PresensiModel?>(
                stream: repo.watchPresensiHariIni(mahasiswaUid: uid, jadwalId: jadwal.id),
                builder: (context, snapshot) {
                  final sudahHadir = snapshot.data != null;
                  if (sudahHadir) {
                    return const Chip(
                      avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
                      label: Text('HADIR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      backgroundColor: AppTheme.success,
                      visualDensity: VisualDensity.compact,
                    );
                  }
                  if (jadwal.isActiveAt(DateTime.now())) {
                    return const Chip(
                      label: Text('Aktif', style: TextStyle(fontSize: 11)),
                      backgroundColor: Color(0xFFDFF5E1),
                      visualDensity: VisualDensity.compact,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
      ),
    );
  }
}
