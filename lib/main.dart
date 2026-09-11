import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.assertConfigured();
  await Future.wait([
    Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey),
    initializeDateFormatting('id_ID'),
  ]);
  runApp(const PresensiApp());
}
