import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/face_crop_util.dart';

class LivenessResult {
  final bool isReal;
  final double confidence;
  final double rawScore;

  const LivenessResult({
    required this.isReal,
    required this.confidence,
    required this.rawScore,
  });
}

class LivenessService {
  static const modelAssetPath = 'assets/models/model.tflite';
  static const inputSize = 224;
  static const int cpuThreads = 4;

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
    Offset? leftEye,
    Offset? rightEye,
  }) {
    final resized = cropFaceFromCameraImage(
      cameraImage: cameraImage,
      boundingBox: boundingBox,
      rotationDegrees: rotationDegrees,
      targetSize: inputSize,
      leftEye: leftEye,
      rightEye: rightEye,
    );
    return classifyCroppedImage(resized);
  }

  /// Runs inference on an already-cropped face image (see [classify]).
  /// Split out so the same crop can be reused for a pre-inference quality
  /// check (blur/brightness) without cropping twice.
  LivenessResult classifyCroppedImage(img.Image croppedFace) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Model liveness belum dimuat. Panggil loadModel() dahulu.');
    }

    final input = _imageToInputTensor(croppedFace);
    final output = List.generate(1, (_) => List.filled(1, 0.0));
    interpreter.run(input, output);
    final score = output[0][0];

    return decide(score);
  }

  /// Pure threshold decision, split out from [classify] so it can be unit
  /// tested without a loaded TFLite interpreter/camera frame.
  static LivenessResult decide(double score) {
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
