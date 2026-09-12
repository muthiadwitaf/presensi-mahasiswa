import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants/app_strings.dart';
import '../core/repositories/attendance_repository.dart';
import '../core/repositories/face_profile_repository.dart';
import '../core/services/face_detection_service.dart';
import '../core/services/face_embedding_service.dart';
import '../core/services/face_quality_service.dart';
import '../core/services/liveness_service.dart';
import '../core/services/location_service.dart';
import '../core/utils/face_crop_util.dart';
import '../models/session_today_model.dart';

enum CekStatus { belum, mengecek, valid, invalid }

class PresensiProvider extends ChangeNotifier {
  PresensiProvider({
    LocationService? locationService,
    FaceDetectionService? faceDetectionService,
    LivenessService? livenessService,
    FaceEmbeddingService? faceEmbeddingService,
    AttendanceRepository? attendanceRepository,
    FaceProfileRepository? faceProfileRepository,
  })  : _locationService = locationService ?? LocationService(),
        _faceDetectionService = faceDetectionService ?? FaceDetectionService(),
        _livenessService = livenessService ?? LivenessService(),
        _faceEmbeddingService = faceEmbeddingService ?? FaceEmbeddingService(),
        _attendanceRepository = attendanceRepository ?? AttendanceRepository(),
        _faceProfileRepository = faceProfileRepository ?? FaceProfileRepository();

  final LocationService _locationService;
  final FaceDetectionService _faceDetectionService;
  final LivenessService _livenessService;
  final FaceEmbeddingService _faceEmbeddingService;
  final AttendanceRepository _attendanceRepository;
  final FaceProfileRepository _faceProfileRepository;

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

  /// Whether the current student already has a registered face profile —
  /// checked before starting the camera, since presensi is impossible
  /// without one.
  Future<bool> wajahSudahTerdaftar() async {
    final status = await _faceProfileRepository.status();
    return status.hasProfile;
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

  Future<void> catatLokasiSaatIni() async {
    try {
      _position = await _locationService.getCurrentPosition();
    } catch (_) {
      _position = null;
    }
    notifyListeners();
  }

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
      if (faces.length > 1) {
        livenessStatus = CekStatus.invalid;
        livenessMessage = AppStrings.gagalWajahLebihDariSatu;
        notifyListeners();
        return;
      }
      final face = faces.first;
      final boundingBox = face.boundingBox;

      final poseIssue = FaceQualityService.checkPose(
        boundingBoxWidth: boundingBox.width,
        boundingBoxHeight: boundingBox.height,
        headEulerAngleY: face.headEulerAngleY,
        headEulerAngleZ: face.headEulerAngleZ,
      );
      if (poseIssue != null) {
        livenessStatus = CekStatus.belum;
        livenessMessage = _qualityMessage(poseIssue);
        notifyListeners();
        return;
      }

      final leftEyePos = face.landmarks[FaceLandmarkType.leftEye]?.position;
      final rightEyePos = face.landmarks[FaceLandmarkType.rightEye]?.position;
      final leftEye = leftEyePos != null ? Offset(leftEyePos.x.toDouble(), leftEyePos.y.toDouble()) : null;
      final rightEye = rightEyePos != null ? Offset(rightEyePos.x.toDouble(), rightEyePos.y.toDouble()) : null;

      final croppedFace = cropFaceFromCameraImage(
        cameraImage: image,
        boundingBox: boundingBox,
        rotationDegrees: rotation,
        targetSize: LivenessService.inputSize,
        leftEye: leftEye,
        rightEye: rightEye,
      );
      final qualityIssue = FaceQualityService.checkCroppedImage(croppedFace);
      if (qualityIssue != null) {
        livenessStatus = CekStatus.belum;
        livenessMessage = _qualityMessage(qualityIssue);
        notifyListeners();
        return;
      }

      final result = _livenessService.classifyCroppedImage(croppedFace);
      livenessConfidence = result.confidence;
      livenessStatus = result.isReal ? CekStatus.valid : CekStatus.invalid;
      livenessMessage = result.isReal ? null : AppStrings.gagalLiveness;
      notifyListeners();

      if (!result.isReal) return;

      final embedding = _faceEmbeddingService.embedFromCameraImage(
        cameraImage: image,
        boundingBox: boundingBox,
        rotationDegrees: rotation,
        leftEye: leftEye,
        rightEye: rightEye,
      );

      await _submitKeServer(sesi: sesi, embedding: embedding, livenessRawScore: result.rawScore);
    } catch (e) {
      errorUmum = 'Gagal memproses frame kamera: $e';
      notifyListeners();
    } finally {
      _isProcessingFrame = false;
    }
  }

  static String _qualityMessage(FaceQualityIssue issue) => switch (issue) {
        FaceQualityIssue.tooFar => AppStrings.gagalWajahTerlaluJauh,
        FaceQualityIssue.pose => AppStrings.gagalPoseWajah,
        FaceQualityIssue.tooDark => AppStrings.gagalWajahTerlaluGelap,
        FaceQualityIssue.tooBright => AppStrings.gagalWajahTerlaluTerang,
        FaceQualityIssue.blurry => AppStrings.gagalWajahBuram,
      };

  Future<void> _submitKeServer({
    required SessionToday sesi,
    required List<double> embedding,
    required double livenessRawScore,
  }) async {
    _submitting = true;
    faceMatchStatus = CekStatus.mengecek;
    notifyListeners();
    try {
      final challenge = await _attendanceRepository.requestChallenge(
        meetingSessionId: sesi.meetingSessionId,
        courseClassId: sesi.meetingSessionId == null ? sesi.courseClassId : null,
        sessionDate: sesi.meetingSessionId == null ? DateTime.now() : null,
      );
      final result = await _attendanceRepository.submitAttendance(
        meetingSessionId: challenge.meetingSessionId,
        probeEmbedding: embedding,
        livenessScore: livenessRawScore,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        accuracyM: _position?.accuracy,
        isMocked: _position?.isMocked,
        challengeNonce: challenge.nonce,
      );
      faceMatchStatus = CekStatus.valid;
      faceMatchMessage = null;
      sudahTercatat = true;
      attendanceIdTercatat = result.attendanceId;
    } on SubmitAttendanceException catch (e) {
      if (e.code == 'FAIL_DUPLICATE') {

        sudahTercatat = true;
        faceMatchStatus = CekStatus.valid;
      } else {
        faceMatchStatus = CekStatus.invalid;
        faceMatchMessage = e.userMessage;

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
