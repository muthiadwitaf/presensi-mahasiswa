import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_liveness/core/utils/face_matching.dart';

void main() {
  group('FaceMatching.euclideanDistance', () {
    test('identical embeddings are zero distance', () {
      expect(FaceMatching.euclideanDistance([1, 2, 3], [1, 2, 3]), 0.0);
    });

    test('matches known 3-4-5 triangle', () {
      expect(FaceMatching.euclideanDistance([0, 0], [3, 4]), 5.0);
    });

    test('throws when dimensions differ', () {
      expect(
        () => FaceMatching.euclideanDistance([1, 2], [1, 2, 3]),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('FaceMatching.isMatch (threshold decision)', () {
    test('distance exactly at threshold matches (inclusive)', () {
      final a = [0.0, 0.0];
      final b = [FaceMatching.threshold, 0.0];
      expect(FaceMatching.isMatch(a, b), isTrue);
    });

    test('distance just over threshold does not match', () {
      final a = [0.0, 0.0];
      final b = [FaceMatching.threshold + 0.01, 0.0];
      expect(FaceMatching.isMatch(a, b), isFalse);
    });

    test('identical vectors always match', () {
      final a = [0.1, 0.2, 0.3, 0.4];
      expect(FaceMatching.isMatch(a, List.of(a)), isTrue);
    });
  });
}
