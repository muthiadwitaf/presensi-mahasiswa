/// Kredensial Supabase, wajib disuplai lewat --dart-define-from-file
/// (lihat env/dev.json) - jangan pernah di-hardcode di sini.
///
/// Jalankan aplikasi dengan:
///   flutter run --dart-define-from-file=env/dev.json
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void assertConfigured() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL/SUPABASE_ANON_KEY belum di-set. Jalankan aplikasi dengan '
        '"flutter run --dart-define-from-file=env/dev.json".',
      );
    }
  }
}
