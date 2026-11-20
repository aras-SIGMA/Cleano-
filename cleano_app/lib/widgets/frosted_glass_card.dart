import 'dart:ui';
import 'package:flutter/material.dart';

/// Komponen Kartu Bergaya iOS Frosted Glass (Glassmorphism):
/// - Bayangan difus lembut di luar kartu (`boxShadow`)
/// - Lapisan transparan gradasi putih dengan specular border
/// - Dukungan blur optis (`BackdropFilter`) dengan opsi performa tinggi (`enableBlur`)
/// - Sudut membulat khas antarmuka iOS
class FrostedGlassCard extends StatelessWidget {
  const FrostedGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20.0,
    this.blurSigma = 16.0,
    this.enableBlur = false,
    this.onTap,
    this.border,
    this.backgroundColor,
    this.gradient,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;

  /// Aktifkan BackdropFilter hanya untuk elemen mengambang diam (seperti bar navigasi).
  /// Untuk kartu di dalam daftar scroll, `enableBlur = false` mempertahankan visual
  /// transparan specular 100% identik namun meniadakan beban saveLayer GPU,
  /// menghasilkan scroll mulus 60-120 FPS tanpa lag.
  final bool enableBlur;

  final VoidCallback? onTap;
  final BoxBorder? border;
  final Color? backgroundColor;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget innerCard = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: backgroundColor,
        gradient: backgroundColor != null
            ? null
            : (gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.86),
                    Colors.white.withValues(alpha: 0.68),
                  ],
                )),
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.88),
              width: 1.2,
            ),
      ),
      child: child,
    );

    if (onTap != null) {
      innerCard = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: innerCard,
        ),
      );
    }

    if (!enableBlur) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: boxShadow ??
              [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
        ),
        child: innerCard,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: innerCard,
        ),
      ),
    );
  }
}
