import 'package:geolocator/geolocator.dart';

/// Menyediakan lokasi live perangkat - direkam sebagai bagian dari log
/// presensi (Clock In/Out), tanpa validasi radius geofence.
class LocationService {
  Future<void> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Izin lokasi ditolak. Aktifkan izin lokasi untuk melakukan presensi.');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Layanan lokasi (GPS) tidak aktif. Aktifkan GPS terlebih dahulu.');
    }
  }

  Future<Position> getCurrentPosition() async {
    await ensurePermission();
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
