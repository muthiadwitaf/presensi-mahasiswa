import 'package:geocoding/geocoding.dart';

class GeocodingService {
  final _geocoding = Geocoding();

  Future<String?> alamatDari(double latitude, double longitude) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final bagian = [p.street, p.subLocality, p.locality].where((s) => s != null && s.isNotEmpty).toList();
      return bagian.isEmpty ? null : bagian.join(', ');
    } catch (_) {
      return null;
    }
  }
}
