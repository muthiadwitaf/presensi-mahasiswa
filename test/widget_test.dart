// Test widget dasar. Test end-to-end penuh (login, presensi, dst) butuh
// Firebase Emulator Suite atau mocking FirebaseAuth/Firestore yang di luar
// scope purwarupa ini - lihat README bagian "Verifikasi" untuk cara
// verifikasi manual di device/emulator Android sungguhan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp dasar bisa dirender tanpa error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('OK'))));
    expect(find.text('OK'), findsOneWidget);
  });
}
