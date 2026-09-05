import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.assertConfigured();
  // Firebase dipertahankan sementara untuk fitur yang belum dimigrasi ke
  // Supabase (jadwal/presensi/izin/notifikasi/matkul/ruang/wajah). Hanya
  // dikonfigurasi untuk Android (lihat firebase_options.dart) - dilewati di
  // platform lain (mis. Windows desktop saat pengembangan UI) supaya tidak
  // crash saat start.
  if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  await initializeDateFormatting('id_ID');
  runApp(const PresensiApp());
}
