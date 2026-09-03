import 'dart:math';

/// Bandingkan dua embedding wajah (hasil MobileFaceNet) pakai jarak
/// Euclidean — pola & nilai threshold ini mengikuti reference implementation
/// Flutter yang jadi sumber model (MCarlomagno/FaceRecognitionAuth,
/// `ml_service.dart`): `threshold = 0.5`, cocok kalau `distance <= threshold`.
class FaceMatching {
  FaceMatching._();

  static const double threshold = 0.5;

  static double euclideanDistance(List<double> a, List<double> b) {
    assert(a.length == b.length, 'Dimensi embedding tidak sama (${a.length} vs ${b.length})');
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  static bool isMatch(List<double> a, List<double> b) => euclideanDistance(a, b) <= threshold;
}
