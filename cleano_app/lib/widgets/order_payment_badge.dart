import 'package:flutter/material.dart';

import 'language_picker_sheet.dart';

/// Badge status pembayaran LUNAS/BELUM BAYAR terpadu untuk kartu kasir dan pelanggan.
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
    final l10n = context.l10n;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isLunas ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isLunas ? l10n.paidBadge : l10n.unpaidBadge,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isLunas ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }
}
