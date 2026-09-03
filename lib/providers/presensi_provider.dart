import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_strings.dart';
import '../core/repositories/presensi_repository.dart';
import '../core/services/face_detection_service.dart';
import '../core/services/face_embedding_service.dart';
import '../core/services/liveness_service.dart';
import '../core/services/location_service.dart';
import '../core/utils/face_matching.dart';
import '../models/jadwal_model.dart';
import '../models/presensi_model.dart';
import '../models/user_model.dart';

enum CekStatus { belum, mengecek, valid, invalid }

/// Mengorkestrasi alur inti presensi: validasi sesi aktif, deteksi wajah +
/// klasifikasi liveness, DAN (Opsi A) pencocokan identitas wajah terhadap
/// data terdaftar per frame kamera - mencatat hasil akhir ke Firestore hanya
/// kalau wajah lolos liveness & cocok dengan data terdaftar. Lokasi live
/// direkam sebagai bagian dari log (bukan syarat lolos/gagal).
class PresensiProvider extends ChangeNotifier {
  PresensiProvider({
    LocationService? locationService,
    FaceDetectionService? faceDetectionService,
    LivenessService? livenessService,
    FaceEmbeddingService? faceEmbeddingService,
    PresensiRepository? presensiRepository,
  })  : _locationService = locationService ?? LocationService(),
        _faceDetectionService = faceDetectionService ?? FaceDetectionService(),
        _livenessService = livenessService ?? LivenessService(),
        _faceEmbeddingService = faceEmbeddingService ?? FaceEmbeddingService(),
        _presensiRepository = presensiRepository ?? PresensiRepository();

  final LocationService _locationService;
  final FaceDetectionService _faceDetectionService;
  final LivenessService _livenessService;
  final FaceEmbeddingService _faceEmbeddingService;
  final PresensiRepository _presensiRepository;

  double? clockInLat;
  double? clockInLng;

  CekStatus livenessStatus = CekStatus.belum;
  double? livenessConfidence;
  String? livenessMessage;

  CekStatus faceMatchStatus = CekStatus.belum;
  double? faceMatchDistance;
  String? faceMatchMessage;

  bool sudahTercatat = false;
  bool gagalDicatat = false;
  String? errorUmum;

  bool _isProcessingFrame = false;
  bool _modelReady = false;
  bool _presensiTersimpan = false;

  Future<void> siapkanModel() async {
    if (_modelReady) return;
    await Future.wait([
      _livenessService.loadModel(),
      _faceEmbeddingService.loadModel(),
    ]);
    _modelReady = true;
  }

  void resetUntukSesiBaru() {
    clockInLat = null;
    clockInLng = null;
    livenessStatus = CekStatus.belum;
    livenessConfidence = null;
    livenessMessage = null;
    faceMatchStatus = CekStatus.belum;
    faceMatchDistance = null;
    faceMatchMessage = null;
    sudahTercatat = false;
    gagalDicatat = false;
    errorUmum = null;
    _presensiTersimpan = false;
    notifyListeners();
  }

  /// Rekam lokasi live perangkat untuk dicatat sebagai bagian dari log
  /// presensi (bukan syarat lolos/gagal) - gagal diam-diam kalau lokasi
  /// tidak tersedia, supaya tidak menghalangi alur presensi.
  Future<void> catatLokasiSaatIni() async {
    try {
      final position = await _locationService.getCurrentPosition();
      clockInLat = position.latitude;
      clockInLng = position.longitude;
    } catch (_) {
      clockInLat = null;
      clockInLng = null;
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
    required JadwalModel sesi,
    required UserModel mahasiswa,
  }) async {
    if (_isProcessingFrame || _presensiTersimpan || !_modelReady) return;
    _isProcessingFrame = true;
    try {
      final wajahTerdaftar = mahasiswa.wajahEmbedding;
      if (wajahTerdaftar == null) {
        faceMatchStatus = CekStatus.invalid;
        faceMatchMessage = AppStrings.gagalBelumDaftarWajah;
        notifyListeners();
        return;
      }

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

      if (!result.isReal) {
        faceMatchStatus = CekStatus.belum;
        faceMatchMessage = null;
        notifyListeners();
        return;
      }

      final embedding = _faceEmbeddingService.embedFromCameraImage(
        cameraImage: image,
        boundingBox: boundingBox,
        rotationDegrees: rotation,
      );
      final distance = FaceMatching.euclideanDistance(embedding, wajahTerdaftar);
      final isMatch = distance <= FaceMatching.threshold;
      faceMatchDistance = distance;
      faceMatchStatus = isMatch ? CekStatus.valid : CekStatus.invalid;
      faceMatchMessage = isMatch ? null : AppStrings.gagalFaceMatch;
      notifyListeners();

      if (isMatch) {
        await _catatPresensi(
          sesi: sesi,
          mahasiswa: mahasiswa,
          livenessConfidence: result.confidence,
          faceMatchDistance: distance,
        );
      }
    } catch (e) {
      errorUmum = 'Gagal memproses frame kamera: $e';
      notifyListeners();
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _catatPresensi({
    required JadwalModel sesi,
    required UserModel mahasiswa,
    required double livenessConfidence,
    required double faceMatchDistance,
  }) async {
    if (_presensiTersimpan) return;
    _presensiTersimpan = true;
    try {
      final sudahAda = await _presensiRepository.sudahPresensiHariIni(
        mahasiswaUid: mahasiswa.uid,
        jadwalId: sesi.id,
      );
      if (sudahAda) {
        sudahTercatat = true;
        notifyListeners();
        return;
      }

      final presensi = PresensiModel(
        id: '',
        jadwalId: sesi.id,
        matkulNama: sesi.matkulNama,
        mahasiswaUid: mahasiswa.uid,
        mahasiswaNama: mahasiswa.nama,
        mahasiswaNim: mahasiswa.nim,
        timestamp: DateTime.now(),
        clockInLat: clockInLat,
        clockInLng: clockInLng,
        statusLiveness: true,
        livenessConfidence: livenessConfidence,
        statusFaceMatch: true,
        faceMatchDistance: faceMatchDistance,
        statusAkhir: StatusAkhir.hadir,
      );
      await _presensiRepository.catat(presensi);
      sudahTercatat = true;
      notifyListeners();
    } catch (e) {
      gagalDicatat = true;
      errorUmum = 'Gagal menyimpan presensi: $e';
      _presensiTersimpan = false;
      notifyListeners();
    }
  }

  bool clockOutBusy = false;
  String? clockOutError;

  /// Clock Out: hanya catat waktu & lokasi (tanpa verifikasi liveness/wajah
  /// ulang, sesuai keputusan produk).
  Future<bool> clockOut(PresensiModel presensi) async {
    clockOutBusy = true;
    clockOutError = null;
    notifyListeners();
    try {
      final position = await _locationService.getCurrentPosition();
      await _presensiRepository.catatClockOut(
        presensi.id,
        waktu: DateTime.now(),
        lat: position.latitude,
        lng: position.longitude,
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
