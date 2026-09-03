import 'package:flutter/material.dart';

import '../../../providers/presensi_provider.dart';
import '../../../widgets/status_badge.dart';

class VerificationStatusWidget extends StatelessWidget {
  const VerificationStatusWidget({super.key, required this.presensi});

  final PresensiProvider presensi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusBadge(
            label: 'Verifikasi Wajah (Liveness)',
            kind: switch (presensi.livenessStatus) {
              CekStatus.belum => StatusBadgeKind.belum,
              CekStatus.mengecek => StatusBadgeKind.proses,
              CekStatus.valid => StatusBadgeKind.berhasil,
              CekStatus.invalid => StatusBadgeKind.gagal,
            },
            subtitle: presensi.livenessMessage ??
                (presensi.livenessConfidence != null
                    ? 'Keyakinan: ${(presensi.livenessConfidence! * 100).toStringAsFixed(1)}%'
                    : 'Posisikan wajah di dalam bingkai'),
          ),
          const SizedBox(height: 12),
          StatusBadge(
            label: 'Kecocokan Identitas Wajah',
            kind: switch (presensi.faceMatchStatus) {
              CekStatus.belum => StatusBadgeKind.belum,
              CekStatus.mengecek => StatusBadgeKind.proses,
              CekStatus.valid => StatusBadgeKind.berhasil,
              CekStatus.invalid => StatusBadgeKind.gagal,
            },
            subtitle: presensi.faceMatchMessage ??
                (presensi.faceMatchStatus == CekStatus.valid
                    ? 'Wajah cocok dengan data terdaftar'
                    : 'Menunggu verifikasi liveness selesai'),
          ),
        ],
      ),
    );
  }
}
