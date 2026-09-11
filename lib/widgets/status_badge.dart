import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum StatusBadgeKind { belum, proses, berhasil, gagal }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.kind,
    this.subtitle,
  });

  final String label;
  final StatusBadgeKind kind;
  final String? subtitle;

  Color get _color {
    switch (kind) {
      case StatusBadgeKind.belum:
        return Colors.grey;
      case StatusBadgeKind.proses:
        return AppTheme.warning;
      case StatusBadgeKind.berhasil:
        return AppTheme.success;
      case StatusBadgeKind.gagal:
        return AppTheme.danger;
    }
  }

  IconData get _icon {
    switch (kind) {
      case StatusBadgeKind.belum:
        return Icons.radio_button_unchecked;
      case StatusBadgeKind.proses:
        return Icons.hourglass_top;
      case StatusBadgeKind.berhasil:
        return Icons.check_circle;
      case StatusBadgeKind.gagal:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_icon, color: _color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, color: _color),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
