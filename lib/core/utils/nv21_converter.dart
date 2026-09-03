import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Konversi buffer NV21 (Y plane + interleaved VU plane, format yang diminta
/// dari `camera` package lewat `ImageFormatGroup.nv21` khusus supaya
/// kompatibel langsung dengan Google ML Kit di Android) menjadi `img.Image`
/// RGB, supaya bisa di-crop & resize sebelum masuk ke TFLite.
///
/// Rumus konversi YUV->RGB standar AOSP (BT.601, full range).
img.Image nv21ToImage(Uint8List nv21, int width, int height) {
  final image = img.Image(width: width, height: height);
  final frameSize = width * height;

  for (int j = 0, yp = 0; j < height; j++) {
    int uvp = frameSize + (j >> 1) * width;
    int u = 0, v = 0;
    for (int i = 0; i < width; i++, yp++) {
      final y = (0xff & nv21[yp]) - 16;
      final yClamped = y < 0 ? 0 : y;
      if ((i & 1) == 0) {
        v = (0xff & nv21[uvp++]) - 128;
        u = (0xff & nv21[uvp++]) - 128;
      }
      final y1192 = 1192 * yClamped;
      var r = (y1192 + 1634 * v) >> 10;
      var g = (y1192 - 833 * v - 400 * u) >> 10;
      var b = (y1192 + 2066 * u) >> 10;
      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);
      image.setPixelRgb(i, j, r, g, b);
    }
  }
  return image;
}
