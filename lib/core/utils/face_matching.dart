import 'dart:math';

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
