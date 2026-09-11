import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'nv21_converter.dart';

img.Image cropFaceFromCameraImage({
  required CameraImage cameraImage,
  required Rect boundingBox,
  required int rotationDegrees,
  required int targetSize,
}) {
  final rawImage = nv21ToImage(
    cameraImage.planes.first.bytes,
    cameraImage.width,
    cameraImage.height,
  );
  final upright = rotationDegrees == 0 ? rawImage : img.copyRotate(rawImage, angle: rotationDegrees);

  final cropRect = _expandAndClampRect(boundingBox, upright.width, upright.height);
  final cropped = img.copyCrop(
    upright,
    x: cropRect.left.toInt(),
    y: cropRect.top.toInt(),
    width: cropRect.width.toInt(),
    height: cropRect.height.toInt(),
  );
  return img.copyResize(cropped, width: targetSize, height: targetSize);
}

Rect _expandAndClampRect(Rect box, int imgWidth, int imgHeight) {
  final marginX = box.width * 0.15;
  final marginY = box.height * 0.15;
  final left = (box.left - marginX).clamp(0, imgWidth - 1).toDouble();
  final top = (box.top - marginY).clamp(0, imgHeight - 1).toDouble();
  final right = (box.right + marginX).clamp(left + 1, imgWidth.toDouble());
  final bottom = (box.bottom + marginY).clamp(top + 1, imgHeight.toDouble());
  return Rect.fromLTRB(left, top, right, bottom);
}
