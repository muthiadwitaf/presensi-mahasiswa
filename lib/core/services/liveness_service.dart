import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/face_crop_util.dart';

class LivenessResult {
  final bool isReal;
  final double confidence; // 0..1, confidence untuk kelas yang diprediksi
  final double rawScore; // skor sigmoid mentah, untuk debugging/kalibrasi

  const LivenessResult({
    required this.isReal,
    required this.confidence,
    required this.rawScore,
  });
}

/// KF-03: klasifikasi wajah terdeteksi ke kelas "real"/"spoof" pakai
/// MobileNetV2 (.tflite). Model yang dipakai: pretrained dari
/// `biometric-technologies/liveness-detection-model` (MIT) — lihat README
/// untuk sumber & cara download. Preprocessing MENGIKUTI kode inferensi asli
/// model itu (pixel/255.0), bukan skema pixel/127.5-1.0 di draf awal proposal.
class LivenessService {
  static const modelAssetPath = 'assets/models/model.tflite';
  static const inputSize = 224;
  static const int cpuThreads = 4;

  /// === KALIBRASI WAJIB SEBELUM DEMO/SIDANG ===
  /// Output model ini satu neuron sigmoid (bukan softmax 2 kelas), tapi arah
  /// labelnya (skor mendekati 1 = "real" atau sebaliknya) BELUM diverifikasi
  /// dari dokumentasi sumber model. Jalankan `scripts/calibrate_model.py`
  /// dengan beberapa contoh foto real & spoof, lalu set konstanta ini sesuai
  /// hasilnya.
  static const bool realIsHighScore = true;
  static const double threshold = 0.5;

  Interpreter? _interpreter;

  bool get isReady => _interpreter != null;

  Future<void> loadModel() async {
    final options = InterpreterOptions()..threads = cpuThreads;
    _interpreter = await Interpreter.fromAsset(modelAssetPath, options: options);
  }

  LivenessResult classify({
    required CameraImage cameraImage,
    required Rect boundingBox,
    required int rotationDegrees,
  }) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Model liveness belum dimuat. Panggil loadModel() dahulu.');
    }

    final resized = cropFaceFromCameraImage(
      cameraImage: cameraImage,
      boundingBox: boundingBox,
      rotationDegrees: rotationDegrees,
      targetSize: inputSize,
    );

    final input = _imageToInputTensor(resized);
    final output = List.generate(1, (_) => List.filled(1, 0.0));
    interpreter.run(input, output);
    final score = output[0][0];

    final probReal = realIsHighScore ? score : (1 - score);
    final isReal = probReal >= threshold;
    final confidence = isReal ? probReal : (1 - probReal);

    return LivenessResult(isReal: isReal, confidence: confidence, rawScore: score);
  }

  List _imageToInputTensor(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        image.height,
        (y) => List.generate(image.width, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
