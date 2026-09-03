import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// KF-02: deteksi wajah (bounding box, bukan face recognition) dari frame
/// kamera memakai Google ML Kit, mode `fast` & `minFaceSize` 0.15 sesuai
/// variabel independen yang ditetapkan di proposal skripsi.
class FaceDetectionService {
  FaceDetectionService()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast,
            minFaceSize: 0.15,
            enableTracking: false,
          ),
        );

  final FaceDetector _detector;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Bangun `InputImage` dari `CameraImage` (format NV21, single plane —
  /// wajib pakai `ImageFormatGroup.nv21` saat inisialisasi CameraController
  /// di Android supaya kompatibel langsung dengan ML Kit). Mengembalikan
  /// null kalau format/orientasi tidak bisa dipetakan (frame itu dilewati).
  /// Derajat rotasi (0/90/180/270) yang perlu diterapkan ke buffer sensor
  /// mentah supaya tegak lurus (upright) menghadap pengguna — dipakai baik
  /// untuk metadata `InputImage` (ML Kit) maupun untuk merotasi ulang frame
  /// secara manual sebelum crop wajah untuk TFLite, supaya koordinat
  /// bounding box dari ML Kit (yang sudah dalam ruang upright) tetap valid.
  int? computeRotationCompensation({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final sensorOrientation = camera.sensorOrientation;
    var rotationCompensation = _orientations[deviceOrientation];
    if (rotationCompensation == null) return null;

    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return rotationCompensation;
  }

  InputImage? buildInputImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final rotationCompensation = computeRotationCompensation(
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (rotationCompensation == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || format != InputImageFormat.nv21) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<List<Face>> detectFaces(InputImage inputImage) {
    return _detector.processImage(inputImage);
  }

  void dispose() {
    _detector.close();
  }
}
