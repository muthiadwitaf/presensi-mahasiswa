import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../constants/face_geometry_config.dart';
import 'nv21_converter.dart';

img.Image cropFaceFromCameraImage({
  required CameraImage cameraImage,
  required Rect boundingBox,
  required int rotationDegrees,
  required int targetSize,
  Offset? leftEye,
  Offset? rightEye,
}) {
  final rawImage = nv21ToImage(
    cameraImage.planes.first.bytes,
    cameraImage.width,
    cameraImage.height,
  );
  final upright = rotationDegrees == 0 ? rawImage : img.copyRotate(rawImage, angle: rotationDegrees);
  return alignAndCropFace(
    image: upright,
    boundingBox: boundingBox,
    targetSize: targetSize,
    leftEye: leftEye,
    rightEye: rightEye,
  );
}

/// Crops [boundingBox] out of [image] for model input, sized to
/// [targetSize]x[targetSize]. When both eye positions are given, the crop is
/// first de-rotated so the eye line is horizontal (face alignment) before
/// the final centered crop — otherwise it falls back to a plain
/// expand-and-crop.
img.Image alignAndCropFace({
  required img.Image image,
  required Rect boundingBox,
  required int targetSize,
  Offset? leftEye,
  Offset? rightEye,
}) {
  if (leftEye == null || rightEye == null) {
    final rect = _expandAndClampRect(boundingBox, image.width, image.height, FaceGeometryConfig.cropMarginRatio);
    final cropped = _cropRect(image, rect);
    return img.copyResize(cropped, width: targetSize, height: targetSize);
  }

  // Generous padded crop centered on the face so rotating it doesn't cut
  // into the face before the final centered crop below.
  final paddedRect = _expandAndClampRect(boundingBox, image.width, image.height, FaceGeometryConfig.alignmentPaddingRatio);
  final region = _cropRect(image, paddedRect);

  final rollDegrees = faceRollAngleDegrees(leftEye, rightEye)
      .clamp(-FaceGeometryConfig.maxAlignmentRollDegrees, FaceGeometryConfig.maxAlignmentRollDegrees);
  // Rotation happens around the region's own center, which approximates the
  // face center since the padded crop above was centered on the bounding box.
  final rotated = rollDegrees == 0 ? region : img.copyRotate(region, angle: -rollDegrees);

  final finalWidth = (boundingBox.width * (1 + 2 * FaceGeometryConfig.cropMarginRatio)).round();
  final finalHeight = (boundingBox.height * (1 + 2 * FaceGeometryConfig.cropMarginRatio)).round();
  final centered = _cropCentered(rotated, finalWidth, finalHeight);
  return img.copyResize(centered, width: targetSize, height: targetSize);
}

/// Angle (degrees) of the line between the eyes relative to horizontal —
/// the roll that needs to be undone (rotate by its negation) so the eyes
/// end up level.
double faceRollAngleDegrees(Offset leftEye, Offset rightEye) {
  final dx = rightEye.dx - leftEye.dx;
  final dy = rightEye.dy - leftEye.dy;
  return math.atan2(dy, dx) * 180 / math.pi;
}

img.Image _cropRect(img.Image image, Rect rect) {
  return img.copyCrop(
    image,
    x: rect.left.toInt(),
    y: rect.top.toInt(),
    width: rect.width.toInt(),
    height: rect.height.toInt(),
  );
}

img.Image _cropCentered(img.Image image, int width, int height) {
  final w = width.clamp(1, image.width);
  final h = height.clamp(1, image.height);
  final x = ((image.width - w) / 2).round().clamp(0, image.width - w);
  final y = ((image.height - h) / 2).round().clamp(0, image.height - h);
  return img.copyCrop(image, x: x, y: y, width: w, height: h);
}

Rect _expandAndClampRect(Rect box, int imgWidth, int imgHeight, double marginRatio) {
  final marginX = box.width * marginRatio;
  final marginY = box.height * marginRatio;
  final left = (box.left - marginX).clamp(0, imgWidth - 1).toDouble();
  final top = (box.top - marginY).clamp(0, imgHeight - 1).toDouble();
  final right = (box.right + marginX).clamp(left + 1, imgWidth.toDouble());
  final bottom = (box.bottom + marginY).clamp(top + 1, imgHeight.toDouble());
  return Rect.fromLTRB(left, top, right, bottom);
}
