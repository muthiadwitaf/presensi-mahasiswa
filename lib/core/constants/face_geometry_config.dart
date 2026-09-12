class FaceGeometryConfig {
  FaceGeometryConfig._();

  /// Minimum face size as a fraction of image width/height, passed to
  /// ML Kit's `FaceDetectorOptions.minFaceSize`. Shared by every face
  /// detector instance in the app so they agree on what counts as "too far".
  static const double minFaceSizeRatio = 0.15;

  /// Extra margin added around a detected face bounding box before cropping
  /// for model input, as a fraction of the box's width/height. Shared by
  /// every crop path (live camera frames and static enrollment photos) so
  /// liveness and face-embedding inference see consistently-framed crops.
  static const double cropMarginRatio = 0.15;

  /// Extra padding (beyond [cropMarginRatio]) used for the initial crop when
  /// eye-landmark alignment will rotate the region, so rotating doesn't cut
  /// into the face before the final centered crop.
  static const double alignmentPaddingRatio = 0.4;

  /// Eye-line tilt beyond which we no longer trust the alignment estimate
  /// (likely a landmark misdetection rather than a genuinely tilted head)
  /// and fall back to an unrotated crop.
  static const double maxAlignmentRollDegrees = 45;
}
