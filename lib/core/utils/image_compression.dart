import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kompresi & encode foto jadi Base64 untuk disimpan LANGSUNG di field
/// dokumen Firestore (foto wajah terdaftar & lampiran bukti izin/sakit) -
/// dipilih supaya tidak perlu Firebase Storage (yang di project ini
/// mensyaratkan upgrade ke paket Blaze + kartu debit/kredit). Konsekuensi:
/// resolusi/kualitas foto diturunkan supaya muat di bawah limit field
/// Firestore (1MB per field, ~1.33MB kalau sudah dalam bentuk Base64).
class ImageCompression {
  ImageCompression._();

  static const int _maxBytes = 500 * 1024;
  static const int _maxDimension = 800;

  static Future<String> compressToBase64(File file) async {
    final bytes = await file.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) {
      throw StateError('Gagal membaca file gambar');
    }

    if (image.width > _maxDimension || image.height > _maxDimension) {
      image = image.width >= image.height
          ? img.copyResize(image, width: _maxDimension)
          : img.copyResize(image, height: _maxDimension);
    }

    var quality = 85;
    Uint8List encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    while (encoded.lengthInBytes > _maxBytes && quality > 20) {
      quality -= 15;
      encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    return base64Encode(encoded);
  }

  static Uint8List decode(String base64String) => base64Decode(base64String);
}
