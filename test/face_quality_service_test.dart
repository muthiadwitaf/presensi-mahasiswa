import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:presensi_liveness/core/services/face_quality_service.dart';

img.Image _solidColor(int size, int r, int g, int b) {
  final image = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return image;
}

// 2-pixel-wide stripes (period 4). A period-2 checkerboard would alias to
// zero under the sharpness metric's centered (x+1)-(x-1) difference, since
// its immediate neighbors on either side are always identical.
img.Image _stripedPattern(int size) {
  final image = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final v = (x ~/ 2) % 2 == 0 ? 255 : 0;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return image;
}

void main() {
  group('FaceQualityService.checkPose', () {
    test('face large enough and facing forward passes', () {
      final issue = FaceQualityService.checkPose(
        boundingBoxWidth: 150,
        boundingBoxHeight: 150,
        headEulerAngleY: 5,
        headEulerAngleZ: -3,
      );
      expect(issue, isNull);
    });

    test('small bounding box is flagged too far', () {
      final issue = FaceQualityService.checkPose(boundingBoxWidth: 40, boundingBoxHeight: 40);
      expect(issue, FaceQualityIssue.tooFar);
    });

    test('excessive yaw is flagged as pose issue', () {
      final issue = FaceQualityService.checkPose(
        boundingBoxWidth: 150,
        boundingBoxHeight: 150,
        headEulerAngleY: 40,
      );
      expect(issue, FaceQualityIssue.pose);
    });

    test('excessive roll is flagged as pose issue', () {
      final issue = FaceQualityService.checkPose(
        boundingBoxWidth: 150,
        boundingBoxHeight: 150,
        headEulerAngleZ: -40,
      );
      expect(issue, FaceQualityIssue.pose);
    });

    test('missing angle data does not falsely reject', () {
      final issue = FaceQualityService.checkPose(boundingBoxWidth: 150, boundingBoxHeight: 150);
      expect(issue, isNull);
    });
  });

  group('FaceQualityService.checkCroppedImage (brightness/blur)', () {
    test('mid-gray, sharp striped pattern passes', () {
      final issue = FaceQualityService.checkCroppedImage(_stripedPattern(40));
      expect(issue, isNull);
    });

    test('near-black image is flagged too dark', () {
      final issue = FaceQualityService.checkCroppedImage(_solidColor(40, 5, 5, 5));
      expect(issue, FaceQualityIssue.tooDark);
    });

    test('near-white image is flagged too bright', () {
      final issue = FaceQualityService.checkCroppedImage(_solidColor(40, 250, 250, 250));
      expect(issue, FaceQualityIssue.tooBright);
    });

    test('flat mid-gray (no texture) is flagged blurry', () {
      final issue = FaceQualityService.checkCroppedImage(_solidColor(40, 128, 128, 128));
      expect(issue, FaceQualityIssue.blurry);
    });
  });

  group('FaceQualityService.averageBrightness / sharpnessScore', () {
    test('averageBrightness of solid color equals that color value', () {
      expect(FaceQualityService.averageBrightness(_solidColor(10, 100, 100, 100)), closeTo(100, 1e-9));
    });

    test('sharpnessScore of a flat image is zero', () {
      expect(FaceQualityService.sharpnessScore(_solidColor(10, 128, 128, 128)), 0.0);
    });

    test('sharpnessScore of a striped pattern is much higher than a flat image', () {
      final flat = FaceQualityService.sharpnessScore(_solidColor(20, 128, 128, 128));
      final sharp = FaceQualityService.sharpnessScore(_stripedPattern(20));
      expect(sharp, greaterThan(flat));
    });
  });
}
