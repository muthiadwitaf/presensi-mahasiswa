import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/session_today_model.dart';
import '../../models/user_model.dart';
import '../../providers/presensi_provider.dart';
import 'widgets/verification_status_widget.dart';

class PresensiFlowScreen extends StatefulWidget {
  const PresensiFlowScreen({
    super.key,
    required this.sesi,
    required this.mahasiswa,
  });

  final SessionToday sesi;
  final UserModel mahasiswa;

  @override
  State<PresensiFlowScreen> createState() => _PresensiFlowScreenState();
}

class _PresensiFlowScreenState extends State<PresensiFlowScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _initializing = true;
  String? _initError;
  Timer? _sesiTicker;
  bool _sesiBerakhir = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _sesiTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final masihAktif = widget.sesi.isActiveNow();
      if (!masihAktif && !_sesiBerakhir) {
        setState(() => _sesiBerakhir = true);
        _stopStream();
      }
    });
  }

  Future<void> _init() async {
    final provider = context.read<PresensiProvider>();
    try {
      final wajahTerdaftar = await provider.wajahSudahTerdaftar();
      if (!wajahTerdaftar) {
        setState(() {
          _initError = AppStrings.gagalBelumDaftarWajah;
          _initializing = false;
        });
        return;
      }

      await provider.siapkanModel();

      unawaited(provider.catatLokasiSaatIni());

      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      await controller.startImageStream(_onFrame);
      _controller = controller;
      _camera = front;
      setState(() => _initializing = false);
    } catch (e) {
      setState(() {
        _initError = '$e';
        _initializing = false;
      });
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final provider = context.read<PresensiProvider>();
    if (!mounted || provider.sudahTercatat || _sesiBerakhir) return;
    final controller = _controller;
    final camera = _camera;
    if (controller == null || camera == null) return;

    await provider.processFrame(
      image: image,
      camera: camera,
      deviceOrientation: controller.value.deviceOrientation,
      sesi: widget.sesi,
    );

    if (provider.sudahTercatat) {
      await _stopStream();
    }
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  Future<void> _cobaLagi() async {
    setState(() {
      _initializing = true;
      _initError = null;
      _sesiBerakhir = false;
    });
    await _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sesiTicker?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presensi = context.watch<PresensiProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.sesi.courseName, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: _buildBody(presensi),
    );
  }

  Widget _buildBody(PresensiProvider presensi) {
    if (_initializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Menyiapkan kamera & model verifikasi...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_sesiBerakhir && !presensi.sudahTercatat) {
      return _buildFullscreenMessage(
        icon: Icons.timer_off,
        color: AppTheme.warning,
        title: 'Jendela Waktu Sesi Berakhir',
        message: 'Waktu presensi untuk sesi ini sudah selesai. Silakan hubungi dosen jika ada kendala.',
        actionLabel: 'Kembali',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    if (_initError != null) {
      return _buildFullscreenMessage(
        icon: Icons.error_outline,
        color: AppTheme.danger,
        title: 'Terjadi Kesalahan',
        message: _initError!,
        actionLabel: 'Coba Lagi',
        onAction: _cobaLagi,
      );
    }

    if (presensi.sudahTercatat) {
      return _buildFullscreenMessage(
        icon: Icons.check_circle,
        color: AppTheme.success,
        title: AppStrings.berhasilPresensi,
        message: '${widget.mahasiswa.nama} • ${widget.sesi.courseName}',
        actionLabel: 'Selesai',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(controller)),
        Center(
          child: Container(
            width: 240,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(
                color: presensi.faceMatchStatus == CekStatus.valid ? AppTheme.success : Colors.white70,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(150),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: VerificationStatusWidget(presensi: presensi),
        ),
      ],
    );
  }

  Widget _buildFullscreenMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
