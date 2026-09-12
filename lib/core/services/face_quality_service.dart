import 'package:image/image.dart' as img;

import '../constants/face_quality_config.dart';

enum FaceQualityIssue { tooFar, pose, tooDark, tooBright, blurry }

class FaceQualityService {
  FaceQualityService._();

  /// Cheap checks using only the detector's own output (no cropping/pixel
  /// access needed) — face size and head pose.
  static FaceQualityIssue? checkPose({
    required double boundingBoxWidth,
    required double boundingBoxHeight,
    double? headEulerAngleY,
    double? headEulerAngleZ,
  }) {
    if (boundingBoxWidth < FaceQualityConfig.minFaceWidthPx ||
        boundingBoxHeight < FaceQualityConfig.minFaceHeightPx) {
      return FaceQualityIssue.tooFar;
    }
    if (headEulerAngleY != null && headEulerAngleY.abs() > FaceQualityConfig.maxYawDegrees) {
      return FaceQualityIssue.pose;
    }
    if (headEulerAngleZ != null && headEulerAngleZ.abs() > FaceQualityConfig.maxRollDegrees) {
      return FaceQualityIssue.pose;
    }
    return null;
  }

  /// Pixel-level checks on an already-cropped face image — brightness and
  /// blur. Takes the crop already produced for liveness inference so no
  /// extra crop/resize pass is needed.
  static FaceQualityIssue? checkCroppedImage(img.Image face) {
    final brightness = averageBrightness(face);
    if (brightness < FaceQualityConfig.minBrightness) return FaceQualityIssue.tooDark;
    if (brightness > FaceQualityConfig.maxBrightness) return FaceQualityIssue.tooBright;
    if (sharpnessScore(face) < FaceQualityConfig.minSharpness) return FaceQualityIssue.blurry;
    return null;
  }

  static double averageBrightness(img.Image image) {
    double sum = 0;
    var count = 0;
    for (final pixel in image) {
      sum += (pixel.r + pixel.g + pixel.b) / 3;
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  /// Mean squared gradient magnitude on the grayscale image — a lightweight
  /// blur proxy (higher = sharper). Not a true Laplacian-variance metric,
  /// but cheap enough to run per-frame on a small (~112-224px) crop.
  static double sharpnessScore(img.Image image) {
    final gray = img.grayscale(image);
    if (gray.width < 3 || gray.height < 3) return 0;
    double sum = 0;
    var count = 0;
    for (var y = 1; y < gray.height - 1; y++) {
      for (var x = 1; x < gray.width - 1; x++) {
        final gx = gray.getPixel(x + 1, y).r - gray.getPixel(x - 1, y).r;
        final gy = gray.getPixel(x, y + 1).r - gray.getPixel(x, y - 1).r;
        sum += (gx * gx + gy * gy).toDouble();
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }
}
