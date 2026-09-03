import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/repositories/user_repository.dart';
import '../../core/services/face_embedding_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_compression.dart';
import '../../providers/auth_provider.dart';

/// Opsi A: foto di sini dipakai untuk DUA hal — (1) referensi visual untuk
/// peninjauan manual dosen & kepatuhan UU PDP, dan (2) sumber embedding wajah
/// (MobileFaceNet) yang dipakai sistem mencocokkan identitas secara otomatis
/// saat presensi (lihat `core/services/face_embedding_service.dart` &
/// `core/utils/face_matching.dart`). Foto disimpan Base64 di Firestore,
/// bukan Firebase Storage - lihat image_compression.dart.
class WajahTerdaftarScreen extends StatefulWidget {
  const WajahTerdaftarScreen({super.key});

  @override
  State<WajahTerdaftarScreen> createState() => _WajahTerdaftarScreenState();
}

class _WajahTerdaftarScreenState extends State<WajahTerdaftarScreen> {
  final _userRepo = UserRepository();
  final _embeddingService = FaceEmbeddingService();
  bool _busy = false;

  @override
  void dispose() {
    _embeddingService.dispose();
    super.dispose();
  }

  Future<void> _ambilFoto() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (xfile == null) return;

    setState(() => _busy = true);
    try {
      final file = File(xfile.path);
      if (!_embeddingService.isReady) {
        await _embeddingService.loadModel();
      }
      final embedding = await _embeddingService.embedFromFile(file);
      if (embedding == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Wajah tidak terdeteksi di foto, coba lagi dengan pencahayaan yang lebih baik'),
          ));
        }
        return;
      }

      final base64 = await ImageCompression.compressToBase64(file);
      await _userRepo.updateFotoWajah(user.uid, base64: base64, embedding: embedding, updatedAt: DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto wajah berhasil diperbarui')));
        // Kalau layar ini dibuka lewat pintasan dari Beranda (bukan tab
        // drawer), otomatis kembali supaya alurnya tidak jadi jalan buntu -
        // mahasiswa langsung bisa lanjut presensi.
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _hapusFoto() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Data Wajah'),
        content: const Text(
          'Foto & data wajah Anda akan dihapus permanen, dan Anda tidak akan bisa '
          'melakukan presensi sampai daftar ulang. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (konfirmasi != true) return;

    setState(() => _busy = true);
    try {
      await _userRepo.hapusFotoWajah(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data wajah dihapus')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder(
      stream: _userRepo.watchUser(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final punyaFoto = user?.fotoWajahBase64 != null;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Foto wajah di sini WAJIB didaftarkan sebelum bisa presensi. Sistem akan '
                'mencocokkan wajah Anda saat presensi dengan foto ini secara otomatis '
                '(face recognition), selain memeriksa keasliannya (liveness). Kelola data '
                'ini sesuai kebutuhan Anda - sesuai UU Pelindungan Data Pribadi soal data biometrik.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: CircleAvatar(
                radius: 90,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    punyaFoto ? MemoryImage(ImageCompression.decode(user!.fotoWajahBase64!)) : null,
                child: !punyaFoto ? const Icon(Icons.person, size: 90, color: Colors.white) : null,
              ),
            ),
            if (punyaFoto && user?.fotoWajahUpdatedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Terakhir diperbarui: ${DateFormat('d MMM y, HH:mm', 'id_ID').format(user!.fotoWajahUpdatedAt!)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _busy ? null : _ambilFoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(punyaFoto ? 'Daftar Ulang (Ambil Foto Baru)' : 'Daftar Foto Wajah'),
            ),
            if (punyaFoto) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _hapusFoto,
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                label: const Text('Hapus Data Wajah', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ],
        );
      },
    );
  }
}
