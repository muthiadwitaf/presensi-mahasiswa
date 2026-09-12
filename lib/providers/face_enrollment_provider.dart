import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/repositories/face_profile_repository.dart';
import '../core/services/face_embedding_service.dart';

class FaceEnrollmentProvider extends ChangeNotifier {
  FaceEnrollmentProvider({
    FaceProfileRepository? faceProfileRepository,
    FaceEmbeddingService? faceEmbeddingService,
  })  : _faceProfileRepository = faceProfileRepository ?? FaceProfileRepository(),
        _faceEmbeddingService = faceEmbeddingService ?? FaceEmbeddingService();

  final FaceProfileRepository _faceProfileRepository;
  final FaceEmbeddingService _faceEmbeddingService;

  bool busy = false;

  Future<FaceProfileStatus> status() => _faceProfileRepository.status();

  Future<String> photoSignedUrl(String path) => _faceProfileRepository.photoSignedUrl(path);

  /// Runs face-embedding extraction + enrollment for a captured photo.
  /// Returns `false` if no face was detected in the photo (not an error —
  /// caller should ask the user to retake it); throws [EnrollFaceException]
  /// on a server-side enrollment failure (quality/cooldown/etc.).
  Future<bool> daftarkanDariFoto(File file) async {
    busy = true;
    notifyListeners();
    try {
      if (!_faceEmbeddingService.isReady) {
        await _faceEmbeddingService.loadModel();
      }
      final embedding = await _faceEmbeddingService.embedFromFile(file);
      if (embedding == null) return false;

      await _faceProfileRepository.enroll(probeEmbedding: embedding, photoBytes: await file.readAsBytes());
      return true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _faceEmbeddingService.dispose();
    super.dispose();
  }
}
