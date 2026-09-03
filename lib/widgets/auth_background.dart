import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Latar gelap bergradasi + "blob" lingkaran blur dekoratif, dipakai di
/// layar login & register - meniru gaya referensi (dark glassmorphism,
/// aksen biru-ungu).
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.authBackgroundGradient),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            left: -60,
            child: _Blob(color: AppTheme.secondary, size: 240),
          ),
          Positioned(
            bottom: -40,
            right: -50,
            child: _Blob(color: AppTheme.accent, size: 200),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.35), shape: BoxShape.circle),
      ),
    );
  }
}

/// Kartu "glassmorphic" (semi transparan + blur) untuk form di atas
/// [AuthBackground].
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
