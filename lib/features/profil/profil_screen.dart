import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/face_profile_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../izin/izin_screen.dart';
import '../jadwal/jadwal_screen.dart';
import '../notifikasi/notifikasi_screen.dart';
import '../wajah/wajah_terdaftar_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _faceProfileRepo = FaceProfileRepository();
  late final Future<FaceProfileStatus> _statusFuture = () {
    final role = context.read<AuthProvider>().currentUser?.role;

    return role == UserRole.dosen ? Future.value(FaceProfileStatus.none) : _faceProfileRepo.status();
  }();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final isDosen = user.role == UserRole.dosen;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _bukaWajahTerdaftar(context),
                  child: Stack(
                    children: [
                      FutureBuilder<FaceProfileStatus>(
                        future: _statusFuture,
                        builder: (context, snapshot) {
                          final photoPath = snapshot.data?.photoPath;
                          if (photoPath == null) {
                            return CircleAvatar(
                              radius: 34,
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                              child: Text(
                                user.nama.isNotEmpty ? user.nama[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primary),
                              ),
                            );
                          }
                          return FutureBuilder<String>(
                            future: _faceProfileRepo.photoSignedUrl(photoPath),
                            builder: (context, urlSnapshot) {
                              return CircleAvatar(
                                radius: 34,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                backgroundImage: urlSnapshot.data != null ? NetworkImage(urlSnapshot.data!) : null,
                              );
                            },
                          );
                        },
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.nama, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${isDosen ? 'NIP' : 'NIM'}: ${user.nim}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(isDosen ? 'Dosen' : 'Mahasiswa', style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _MenuTile(
          icon: Icons.calendar_month_outlined,
          label: 'Kalender Akademik',
          onTap: () => _pushScaffold(context, 'Kalender Akademik', const JadwalScreen()),
        ),
        if (!isDosen)
          _MenuTile(
            icon: Icons.event_note_outlined,
            label: 'Izin/Sakit',
            onTap: () => _pushScaffold(context, 'Izin/Sakit', const IzinScreen()),
          ),
        _MenuTile(
          icon: Icons.notifications_none,
          label: 'Notifikasi',
          onTap: () => _pushScaffold(context, 'Notifikasi', const NotifikasiScreen()),
        ),
        const SizedBox(height: 16),
        _MenuTile(
          icon: Icons.logout,
          label: 'Keluar',
          color: AppTheme.danger,
          onTap: () => context.read<AuthProvider>().logout(),
        ),
      ],
    );
  }

  void _bukaWajahTerdaftar(BuildContext context) {
    _pushScaffold(context, 'Wajah Terdaftar', const WajahTerdaftarScreen());
  }

  void _pushScaffold(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.textSecondary),
        title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w500)),
        trailing: color == null ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary) : null,
        onTap: onTap,
      ),
    );
  }
}
