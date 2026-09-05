import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/session_today_model.dart';
import '../../../providers/presensi_provider.dart';

/// Kartu "Absensi Hari Ini" - tata letak sengaja dibuat ringkas & satu
/// layar (label + chip status, jam sesi, baris peringatan+tombol aksi,
/// baris status wajah terdaftar) meniru pola app HR yang sudah lazim
/// dipakai, bukan checklist panjang bernomor.
class SessionStatusCard extends StatelessWidget {
  const SessionStatusCard({
    super.key,
    required this.sesi,
    required this.presensi,
    required this.wajahTerdaftar,
    required this.onMulaiPresensi,
    required this.onDaftarWajah,
    required this.onClockOut,
  });

  final SessionToday? sesi;
  final PresensiProvider presensi;
  final bool wajahTerdaftar;
  final VoidCallback onMulaiPresensi;
  final VoidCallback onDaftarWajah;
  final VoidCallback onClockOut;

  @override
  Widget build(BuildContext context) {
    final adaSesi = sesi != null;
    final sudahClockIn = sesi?.sudahClockIn ?? false;
    final sudahClockOut = sesi?.sudahClockOut ?? false;

    final (String statusLabel, Color statusColor) = sudahClockOut
        ? ('Selesai', AppTheme.success)
        : sudahClockIn
            ? ('Sudah Absen', AppTheme.success)
            : ('Belum Absen', Colors.grey.shade600);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  'ABSENSI HARI INI',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(statusLabel, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: statusColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              adaSesi ? sesi!.courseName : 'Tidak ada sesi aktif',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (adaSesi)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${sesi!.startTimeLabel} → ${sesi!.endTimeLabel}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            if (sudahClockIn) ...[
              _BerhasilBanner(sesi: sesi!),
              const SizedBox(height: 10),
              if (sesi!.checkInLatitude != null && sesi!.checkInLongitude != null) ...[
                _LocationRow(latitude: sesi!.checkInLatitude!, longitude: sesi!.checkInLongitude!),
                const SizedBox(height: 10),
              ],
            ],
            if (sudahClockOut)
              _ClockSummary(sesi: sesi!)
            else if (sudahClockIn)
              _buildClockOutRow(context)
            else
              _buildClockInRow(context, adaSesi),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildWajahRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildClockInRow(BuildContext context, bool adaSesi) {
    String? peringatan;
    if (!adaSesi) {
      peringatan = 'Tidak ada mata kuliah aktif saat ini';
    } else if (!wajahTerdaftar) {
      peringatan = 'Daftarkan wajah terlebih dahulu';
    }
    final bisaMulai = adaSesi && wajahTerdaftar;

    return Row(
      children: [
        if (peringatan != null)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(peringatan, style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
                  ),
                ],
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: bisaMulai ? onMulaiPresensi : null,
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Clock In'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
        ),
      ],
    );
  }

  Widget _buildClockOutRow(BuildContext context) {
    final bisaClockOut = sesi?.isActiveNow() ?? false;
    final jamMasuk = sesi?.checkInAt;
    return Row(
      children: [
        Expanded(
          child: Text(
            bisaClockOut && jamMasuk != null
                ? 'Sudah Clock In pukul ${DateFormat('HH:mm').format(jamMasuk)}'
                : 'Clock Out hanya bisa selama sesi masih berlangsung',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: bisaClockOut && !presensi.clockOutBusy ? onClockOut : null,
          icon: presensi.clockOutBusy
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.logout, size: 18),
          label: Text(presensi.clockOutBusy ? '...' : 'Clock Out'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.danger,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildWajahRow(BuildContext context) {
    return Row(
      children: [
        Icon(
          wajahTerdaftar ? Icons.check_circle : Icons.error_outline,
          size: 18,
          color: wajahTerdaftar ? AppTheme.success : AppTheme.warning,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            wajahTerdaftar ? 'Wajah terdaftar' : 'Wajah belum terdaftar',
            style: TextStyle(
              fontSize: 13.5,
              color: wajahTerdaftar ? Colors.black87 : AppTheme.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (wajahTerdaftar)
          IconButton(
            onPressed: onDaftarWajah,
            icon: const Icon(Icons.visibility_outlined, size: 20, color: AppTheme.textSecondary),
            tooltip: 'Lihat foto terdaftar',
            visualDensity: VisualDensity.compact,
          ),
        TextButton.icon(
          onPressed: onDaftarWajah,
          icon: const Icon(Icons.camera_alt_outlined, size: 16),
          label: Text(wajahTerdaftar ? 'Daftar Ulang' : 'Daftar Sekarang'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        ),
      ],
    );
  }
}

/// Banner hijau setelah Clock In berhasil - "Tepat waktu" atau "Terlambat
/// X menit" berdasarkan status & minutes_late dari server (submit-attendance),
/// bukan dihitung ulang di client.
class _BerhasilBanner extends StatelessWidget {
  const _BerhasilBanner({required this.sesi});
  final SessionToday sesi;

  @override
  Widget build(BuildContext context) {
    final terlambat = sesi.attendanceStatus == 'TERLAMBAT' && (sesi.minutesLate ?? 0) > 0;
    final keterangan = terlambat ? 'Terlambat ${sesi.minutesLate} menit.' : 'Tepat waktu!';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (terlambat ? AppTheme.warning : AppTheme.success).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: terlambat ? AppTheme.warning : AppTheme.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Clock In ${sesi.courseName} berhasil. $keterangan',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris lokasi (alamat hasil reverse geocoding) - gagal-diam (tidak
/// ditampilkan) kalau alamat tidak bisa didapat, lihat [GeocodingService].
class _LocationRow extends StatefulWidget {
  const _LocationRow({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;

  @override
  State<_LocationRow> createState() => _LocationRowState();
}

class _LocationRowState extends State<_LocationRow> {
  final _geocoding = GeocodingService();
  String? _alamat;

  @override
  void initState() {
    super.initState();
    _geocoding.alamatDari(widget.latitude, widget.longitude).then((a) {
      if (mounted) setState(() => _alamat = a);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_alamat == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(_alamat!, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        ),
      ],
    );
  }
}

class _ClockSummary extends StatelessWidget {
  const _ClockSummary({required this.sesi});

  final SessionToday sesi;

  @override
  Widget build(BuildContext context) {
    final jam = DateFormat('HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt, size: 18, color: AppTheme.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Clock In ${sesi.checkInAt != null ? jam.format(sesi.checkInAt!) : '-'} • '
              'Clock Out ${sesi.checkOutAt != null ? jam.format(sesi.checkOutAt!) : '-'}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
