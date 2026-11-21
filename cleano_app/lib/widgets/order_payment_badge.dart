import 'package:flutter/material.dart';

/// Badge status pembayaran pesanan: `LUNAS` atau `BELUM BAYAR`.
/// Dipakai kartu kasir dan kartu pelacakan pelanggan supaya tidak ada dua
/// salinan aturan warna/teks yang bisa berbeda pendapat.
class OrderPaymentBadge extends StatelessWidget {
  const OrderPaymentBadge({
    super.key,
    required this.isLunas,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  final bool isLunas;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isLunas ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isLunas ? 'LUNAS' : 'BELUM BAYAR',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isLunas ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }
}
