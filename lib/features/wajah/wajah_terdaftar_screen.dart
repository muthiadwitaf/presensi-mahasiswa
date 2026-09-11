import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/face_profile_repository.dart';
import '../../core/services/face_embedding_service.dart';
import '../../core/theme/app_theme.dart';

class WajahTerdaftarScreen extends StatefulWidget {
  const WajahTerdaftarScreen({super.key});

  @override
  State<WajahTerdaftarScreen> createState() => _WajahTerdaftarScreenState();
}

class _WajahTerdaftarScreenState extends State<WajahTerdaftarScreen> {
  final _faceProfileRepo = FaceProfileRepository();
  final _embeddingService = FaceEmbeddingService();
  bool _busy = false;
  late Future<FaceProfileStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _faceProfileRepo.status();
  }

  @override
  void dispose() {
    _embeddingService.dispose();
    super.dispose();
  }

  Future<void> _ambilFoto() async {
    final picker = ImagePicker();

    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1024,
      imageQuality: 75,
    );
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

      await _faceProfileRepo.enroll(probeEmbedding: embedding, photoBytes: await file.readAsBytes());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto wajah berhasil didaftarkan')));
        setState(() => _statusFuture = _faceProfileRepo.status());

        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).maybePop();
      }
    } on EnrollFaceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FaceProfileStatus>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final status = snapshot.data!;
        final punyaFoto = status.hasProfile;
        final photoPath = status.photoPath;

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
                'mencocokkan wajah Anda saat presensi dengan foto ini (face recognition), '
                'sekaligus memeriksa keasliannya (liveness).',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: photoPath == null
                  ? CircleAvatar(
                      radius: 90,
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(
                        punyaFoto ? Icons.check_circle : Icons.person,
                        size: punyaFoto ? 72 : 90,
                        color: punyaFoto ? AppTheme.success : Colors.white,
                      ),
                    )
                  : FutureBuilder<String>(
                      future: _faceProfileRepo.photoSignedUrl(photoPath),
                      builder: (context, urlSnapshot) {
                        return CircleAvatar(
                          radius: 90,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: urlSnapshot.data != null ? NetworkImage(urlSnapshot.data!) : null,
                          child: urlSnapshot.data == null
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                        );
                      },
                    ),
            ),
            if (punyaFoto && status.updatedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Terakhir diperbarui: ${DateFormat('d MMM y, HH:mm', 'id_ID').format(status.updatedAt!)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _busy ? null : _ambilFoto,
              icon: _busy
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt),
              label: Text(punyaFoto ? 'Daftar Ulang (Ambil Foto Baru)' : 'Daftar Foto Wajah'),
            ),
          ],
        );
      },
    );
  }
}
