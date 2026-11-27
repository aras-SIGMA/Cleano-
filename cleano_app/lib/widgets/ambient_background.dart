import 'package:flutter/material.dart';

/// Latar belakang aurora untuk layar kasir agar gradasi selalu konsisten.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEBF4FF), // soft sky tint
                    Color(0xFFF5F3FF), // soft lavender tint
                    Color(0xFFF8FAFC), // neutral slate
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF93C5FD).withValues(alpha: 0.35),
                      const Color(0xFF93C5FD).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 240,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC4B5FD).withValues(alpha: 0.25),
                      const Color(0xFFC4B5FD).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}