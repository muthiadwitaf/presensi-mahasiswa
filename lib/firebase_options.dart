// File ini adalah PLACEHOLDER, bukan hasil `flutterfire configure` asli.
// Sebelum menjalankan app dengan Firebase sungguhan, WAJIB jalankan:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// di root project ini (login pakai akun Google Anda sendiri untuk membuat
// project Firebase baru / pilih yang sudah ada). Perintah itu akan
// menimpa file ini dengan konfigurasi asli. Lihat README.md bagian
// "Setup Firebase" untuk langkah lengkap.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web belum dikonfigurasi. Jalankan flutterfire configure.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Platform ini belum dikonfigurasi. Jalankan flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDgM6Vv2zZyDI3k7ZlbtQeeiVHsfF79BWw',
    appId: '1:299716148859:android:a1e4c702a6d347d529ecde',
    messagingSenderId: '299716148859',
    projectId: 'presensi-liveness-usm',
    storageBucket: 'presensi-liveness-usm.firebasestorage.app',
  );
}
