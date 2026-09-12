import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_liveness/core/utils/face_crop_util.dart';

void main() {
  group('faceRollAngleDegrees', () {
    test('level eyes (same y) is zero roll', () {
      expect(faceRollAngleDegrees(const Offset(10, 50), const Offset(50, 50)), 0.0);
    });

    test('right eye lower than left eye is a positive roll', () {
      final angle = faceRollAngleDegrees(const Offset(10, 50), const Offset(50, 60));
      expect(angle, greaterThan(0));
    });

    test('right eye higher than left eye is a negative roll', () {
      final angle = faceRollAngleDegrees(const Offset(10, 60), const Offset(50, 50));
      expect(angle, lessThan(0));
    });

    test('45 degree tilt is computed correctly', () {
      final angle = faceRollAngleDegrees(const Offset(0, 0), const Offset(10, 10));
      expect(angle, closeTo(45.0, 1e-9));
    });
  });
}
