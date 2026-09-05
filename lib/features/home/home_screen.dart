import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/attendance_repository.dart';
import '../../core/repositories/face_profile_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../models/session_today_model.dart';
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
  final _attendanceRepo = AttendanceRepository();
  final _faceProfileRepo = FaceProfileRepository();
  late Future<bool> _wajahTerdaftarFuture;

  @override
  void initState() {
    super.initState();
    _wajahTerdaftarFuture = _faceProfileRepo.status().then((s) => s.hasProfile);
    WidgetsBinding.instance.addPostFrameCallback((_) => _muatJadwal());
    // Postgres bukan realtime stream seperti Firestore dulu - refresh
    // berkala supaya jendela waktu sesi & data tetap akurat.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _muatJadwal());
  }

  void _muatJadwal() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final jadwalProvider = context.read<JadwalProvider>();
    if (user.role == UserRole.dosen) {
      jadwalProvider.refreshDosen();
    } else {
      jadwalProvider.refreshMahasiswa();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _bukaPresensi(SessionToday sesi) async {
    final mahasiswa = context.read<AuthProvider>().currentUser!;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresensiFlowScreen(sesi: sesi, mahasiswa: mahasiswa),
      ),
    );
    if (mounted) {
      context.read<PresensiProvider>().resetUntukSesiBaru();
      _muatJadwal();
    }
  }

  Future<void> _clockOut(String attendanceId) async {
    final provider = context.read<PresensiProvider>();
    final ok = await provider.clockOut(attendanceId);
    if (ok) {
      _muatJadwal();
    } else if (mounted && provider.clockOutError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.clockOutError!)));
    }
  }

  void _bukaDaftarWajah() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Wajah Terdaftar')),
              body: const WajahTerdaftarScreen(),
            ),
          ),
        )
        .then((_) => setState(() => _wajahTerdaftarFuture = _faceProfileRepo.status().then((s) => s.hasProfile)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final jadwalProvider = context.watch<JadwalProvider>();
    final isDosen = user.role == UserRole.dosen;
    final sesiHariIni = isDosen ? jadwalProvider.sesiDosenHariIni : jadwalProvider.sesiMahasiswaHariIni;

    return RefreshIndicator(
      onRefresh: () async => _muatJadwal(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Greeting(nama: user.nama),
          const SizedBox(height: 16),
          if (!isDosen) ...[
            _buildPresensiCard(context, jadwalProvider),
            const SizedBox(height: 16),
            _KehadiranSemesterCard(repo: _attendanceRepo),
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
          if (jadwalProvider.isLoading && sesiHariIni.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (sesiHariIni.isEmpty)
            const EmptyState(message: 'Tidak ada jadwal mata kuliah hari ini', icon: Icons.event_busy)
          else
            ...sesiHariIni.map((s) => _JadwalHariIniCard(sesi: s, tampilkanStatus: !isDosen)),
        ],
      ),
    );
  }

  Widget _buildPresensiCard(BuildContext context, JadwalProvider jadwalProvider) {
    final presensiProvider = context.watch<PresensiProvider>();
    final sesi = jadwalProvider.sesiAktifSekarang();

    return FutureBuilder<bool>(
      future: _wajahTerdaftarFuture,
      builder: (context, snapshot) {
        final wajahTerdaftar = snapshot.data ?? false;
        return SessionStatusCard(
          sesi: sesi,
          presensi: presensiProvider,
          wajahTerdaftar: wajahTerdaftar,
          onMulaiPresensi: sesi == null ? () {} : () => _bukaPresensi(sesi),
          onDaftarWajah: _bukaDaftarWajah,
          onClockOut: sesi?.attendanceId == null ? () {} : () => _clockOut(sesi!.attendanceId!),
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
  const _KehadiranSemesterCard({required this.repo});
  final AttendanceRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.myAttendanceHistory(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        final hadir = logs.where((l) => l['status'] == 'HADIR' || l['status'] == 'TERLAMBAT').length;
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
  const _JadwalHariIniCard({required this.sesi, required this.tampilkanStatus});

  final SessionToday sesi;
  final bool tampilkanStatus;

  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (tampilkanStatus && sesi.sudahClockIn) {
      trailing = const Chip(
        avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
        label: Text('HADIR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.success,
        visualDensity: VisualDensity.compact,
      );
    } else if (sesi.isActiveNow()) {
      trailing = const Chip(
        label: Text('Aktif', style: TextStyle(fontSize: 11)),
        backgroundColor: Color(0xFFDFF5E1),
        visualDensity: VisualDensity.compact,
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule, color: AppTheme.textSecondary),
        title: Text(sesi.courseName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${sesi.startTimeLabel} - ${sesi.endTimeLabel} • '
          '${sesi.mode == 'ONLINE' ? 'Online' : sesi.locationName ?? 'Offline'}'
          '${sesi.lecturerName != null ? ' • ${sesi.lecturerName}' : ''}',
        ),
        trailing: trailing,
      ),
    );
  }
}
