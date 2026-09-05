import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants/app_strings.dart';
import '../core/repositories/attendance_repository.dart';
import '../core/services/face_detection_service.dart';
import '../core/services/face_embedding_service.dart';
import '../core/services/liveness_service.dart';
import '../core/services/location_service.dart';
import '../models/session_today_model.dart';

enum CekStatus { belum, mengecek, valid, invalid }

/// Mengorkestrasi alur inti presensi di device: deteksi wajah + klasifikasi
/// liveness + hitung embedding (semua on-device, throttled per frame lewat
/// `_isProcessingFrame`). Keputusan HADIR/valid/tidak TIDAK dibuat di sini -
/// hasil klasifikasi lokal cuma dikirim sebagai evidence ke Edge Function
/// `submit-attendance`, yang jadi satu-satunya penentu status (lihat
/// `AttendanceRepository`). Provider ini cuma menerjemahkan respons server
/// ke state UI.
class PresensiProvider extends ChangeNotifier {
  PresensiProvider({
    LocationService? locationService,
    FaceDetectionService? faceDetectionService,
    LivenessService? livenessService,
    FaceEmbeddingService? faceEmbeddingService,
    AttendanceRepository? attendanceRepository,
  })  : _locationService = locationService ?? LocationService(),
        _faceDetectionService = faceDetectionService ?? FaceDetectionService(),
        _livenessService = livenessService ?? LivenessService(),
        _faceEmbeddingService = faceEmbeddingService ?? FaceEmbeddingService(),
        _attendanceRepository = attendanceRepository ?? AttendanceRepository();

  final LocationService _locationService;
  final FaceDetectionService _faceDetectionService;
  final LivenessService _livenessService;
  final FaceEmbeddingService _faceEmbeddingService;
  final AttendanceRepository _attendanceRepository;

  Position? _position;

  CekStatus livenessStatus = CekStatus.belum;
  double? livenessConfidence;
  String? livenessMessage;

  CekStatus faceMatchStatus = CekStatus.belum;
  String? faceMatchMessage;

  bool sudahTercatat = false;
  bool gagalDicatat = false;
  String? errorUmum;
  String? attendanceIdTercatat;

  bool _isProcessingFrame = false;
  bool _modelReady = false;
  bool _submitting = false;

  Future<void> siapkanModel() async {
    if (_modelReady) return;
    await Future.wait([
      _livenessService.loadModel(),
      _faceEmbeddingService.loadModel(),
    ]);
    _modelReady = true;
  }

  void resetUntukSesiBaru() {
    livenessStatus = CekStatus.belum;
    livenessConfidence = null;
    livenessMessage = null;
    faceMatchStatus = CekStatus.belum;
    faceMatchMessage = null;
    sudahTercatat = false;
    gagalDicatat = false;
    errorUmum = null;
    attendanceIdTercatat = null;
    _submitting = false;
    notifyListeners();
  }

  /// Rekam lokasi live perangkat untuk dikirim sebagai evidence ke server -
  /// gagal diam-diam kalau lokasi tidak tersedia (server yang memutuskan
  /// apakah lokasi wajib untuk sesi ini, lihat FAIL_MODE_MISMATCH/
  /// FAIL_GEOFENCE di `submit-attendance`).
  Future<void> catatLokasiSaatIni() async {
    try {
      _position = await _locationService.getCurrentPosition();
    } catch (_) {
      _position = null;
    }
    notifyListeners();
  }

  /// Dipanggil untuk setiap frame dari `startImageStream`. Frame diabaikan
  /// selama masih memproses frame sebelumnya (throttle alami) supaya UI
  /// tidak jank dan inferensi TFLite tidak overload.
  Future<void> processFrame({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
    required SessionToday sesi,
  }) async {
    if (_isProcessingFrame || sudahTercatat || _submitting || !_modelReady) return;
    _isProcessingFrame = true;
    try {
      final rotation = _faceDetectionService.computeRotationCompensation(
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
      final inputImage = _faceDetectionService.buildInputImage(
        image: image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
      if (inputImage == null || rotation == null) return;

      final faces = await _faceDetectionService.detectFaces(inputImage);
      if (faces.isEmpty) {
        livenessStatus = CekStatus.belum;
        livenessMessage = AppStrings.gagalWajahTidakTerdeteksi;
        notifyListeners();
        return;
      }
      final boundingBox = faces.first.boundingBox;

      final result = _livenessService.classify(
        cameraImage: image,
        boundingBox: boundingBox,
        rotationDegrees: rotation,
      );
      livenessConfidence = result.confidence;
      livenessStatus = result.isReal ? CekStatus.valid : CekStatus.invalid;
      livenessMessage = result.isReal ? null : AppStrings.gagalLiveness;
      notifyListeners();

      // Pre-filter lokal murni untuk menghemat panggilan server (jangan
      // submit setiap frame) - keputusan REAL/SPOOF final tetap di server
      // lewat threshold `anti_spoof_threshold`, skor mentah tetap dikirim.
      if (!result.isReal) return;

      final embedding = _faceEmbeddingService.embedFromCameraImage(
        cameraImage: image,
        boundingBox: boundingBox,
        rotationDegrees: rotation,
      );

      await _submitKeServer(sesi: sesi, embedding: embedding, livenessRawScore: result.rawScore);
    } catch (e) {
      errorUmum = 'Gagal memproses frame kamera: $e';
      notifyListeners();
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _submitKeServer({
    required SessionToday sesi,
    required List<double> embedding,
    required double livenessRawScore,
  }) async {
    _submitting = true;
    faceMatchStatus = CekStatus.mengecek;
    notifyListeners();
    try {
      final result = await _attendanceRepository.submitAttendance(
        meetingSessionId: sesi.meetingSessionId,
        courseClassId: sesi.meetingSessionId == null ? sesi.courseClassId : null,
        sessionDate: sesi.meetingSessionId == null ? DateTime.now() : null,
        probeEmbedding: embedding,
        livenessScore: livenessRawScore,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        accuracyM: _position?.accuracy,
        isMocked: _position?.isMocked,
      );
      faceMatchStatus = CekStatus.valid;
      faceMatchMessage = null;
      sudahTercatat = true;
      attendanceIdTercatat = result.attendanceId;
    } on SubmitAttendanceException catch (e) {
      if (e.code == 'FAIL_DUPLICATE') {
        // Sudah tercatat dari percobaan sebelumnya - bukan kegagalan.
        sudahTercatat = true;
        faceMatchStatus = CekStatus.valid;
      } else {
        faceMatchStatus = CekStatus.invalid;
        faceMatchMessage = e.userMessage;
        // Kegagalan yang terkait wajah boleh dicoba ulang frame berikutnya;
        // kegagalan sesi/duplikat/dsb bersifat final untuk sesi ini.
        if (e.code != 'FAIL_LIVENESS' && e.code != 'FAIL_FACE_MATCH') {
          gagalDicatat = true;
          errorUmum = e.userMessage;
        }
      }
    } catch (e) {
      gagalDicatat = true;
      errorUmum = 'Gagal menghubungi server: $e';
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  bool clockOutBusy = false;
  String? clockOutError;

  /// Clock Out: hanya catat waktu & lokasi (tanpa verifikasi liveness/wajah
  /// ulang, sesuai keputusan produk) - lewat Edge Function `submit-checkout`.
  Future<bool> clockOut(String attendanceId) async {
    clockOutBusy = true;
    clockOutError = null;
    notifyListeners();
    try {
      final position = await _locationService.getCurrentPosition();
      await _attendanceRepository.submitCheckout(
        attendanceId: attendanceId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return true;
    } catch (e) {
      clockOutError = 'Gagal mencatat clock out: $e';
      return false;
    } finally {
      clockOutBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _faceDetectionService.dispose();
    _livenessService.dispose();
    _faceEmbeddingService.dispose();
    super.dispose();
  }
}
