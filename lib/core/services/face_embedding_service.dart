import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/face_crop_util.dart';

class FaceEmbeddingService {
  static const modelAssetPath = 'assets/models/mobilefacenet.tflite';
  static const inputSize = 112;
  static const embeddingSize = 192;
  static const int cpuThreads = 4;

  Interpreter? _interpreter;
  final FaceDetector _fileFaceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate, minFaceSize: 0.15),
  );

  bool get isReady => _interpreter != null;

  Future<void> loadModel() async {
    final options = InterpreterOptions()..threads = cpuThreads;
    _interpreter = await Interpreter.fromAsset(modelAssetPath, options: options);
  }

  List<double> embedFromCameraImage({
    required CameraImage cameraImage,
    required Rect boundingBox,
    required int rotationDegrees,
  }) {
    final face = cropFaceFromCameraImage(
      cameraImage: cameraImage,
      boundingBox: boundingBox,
      rotationDegrees: rotationDegrees,
      targetSize: inputSize,
    );
    return _runEmbedding(face);
  }

  Future<List<double>?> embedFromFile(File file) async {
    final inputImage = InputImage.fromFilePath(file.path);
    final faces = await _fileFaceDetector.processImage(inputImage);
    if (faces.isEmpty) return null;

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final box = faces.first.boundingBox;
    final marginX = box.width * 0.15;
    final marginY = box.height * 0.15;
    final left = (box.left - marginX).clamp(0, decoded.width - 1).toInt();
    final top = (box.top - marginY).clamp(0, decoded.height - 1).toInt();
    final right = (box.right + marginX).clamp(left + 1, decoded.width.toDouble()).toInt();
    final bottom = (box.bottom + marginY).clamp(top + 1, decoded.height.toDouble()).toInt();

    final cropped = img.copyCrop(decoded, x: left, y: top, width: right - left, height: bottom - top);
    final resized = img.copyResize(cropped, width: inputSize, height: inputSize);
    return _runEmbedding(resized);
  }

  List<double> _runEmbedding(img.Image face) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Model face embedding belum dimuat. Panggil loadModel() dahulu.');
    }

    final input = List.generate(
      1,
      (_) => List.generate(
        face.height,
        (y) => List.generate(face.width, (x) {
          final pixel = face.getPixel(x, y);
          return [
            (pixel.r - 128) / 128,
            (pixel.g - 128) / 128,
            (pixel.b - 128) / 128,
          ];
        }),
      ),
    );
    final output = List.generate(1, (_) => List.filled(embeddingSize, 0.0));
    interpreter.run(input, output);
    return List<double>.from(output[0]);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _fileFaceDetector.close();
  }
}
