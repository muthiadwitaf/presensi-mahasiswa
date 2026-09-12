/// Thresholds for the pre-recognition face-quality gate (item #6:
/// reject a frame before running liveness/face-match if the face is too
/// far, too tilted, too dark/bright, or too blurry).
///
/// **Not yet calibrated** against real capture conditions or devices —
/// same caveat as `LivenessService.threshold` / `FaceMatching.threshold`
/// (see README "Model Liveness" / "Model Face Recognition"). These are
/// permissive defaults chosen so the gate is functional but rarely
/// triggers false rejections before proper testing; tighten them once you
/// have real distance/lighting test data (see the pengujian jarak wajah /
/// kondisi pencahayaan items).
class FaceQualityConfig {
  FaceQualityConfig._();

  /// Minimum face bounding-box width/height in pixels (in the camera
  /// frame's own coordinate space) below which the face is considered too
  /// far from the camera. Chosen well above ML Kit's own `minFaceSize`
  /// cutoff so a clearer "move closer" message can be shown instead of a
  /// generic "no face detected".
  static const double minFaceWidthPx = 90;
  static const double minFaceHeightPx = 90;

  /// Max head yaw (left/right turn) and roll (tilt) in degrees before the
  /// pose is considered too far off-axis for reliable liveness/matching.
  static const double maxYawDegrees = 25;
  static const double maxRollDegrees = 25;

  /// Average luminance (0-255) of the cropped face outside which the image
  /// is considered too dark or overexposed.
  static const double minBrightness = 50;
  static const double maxBrightness = 210;

  /// Minimum sharpness score (mean squared gradient magnitude on the
  /// grayscale crop) below which the face is considered too blurry. A
  /// lightweight proxy for a full Laplacian-variance blur metric.
  static const double minSharpness = 80;
}
