import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/voucher_model.dart';
import 'language_picker_sheet.dart';

/// Komponen pemilih / input kode voucher diskon di POS Kasir.
class VoucherField extends StatefulWidget {
  const VoucherField({
    super.key,
    required this.availableVouchers,
    required this.selectedVoucher,
    required this.onVoucherChanged,
  });

  final List<VoucherModel> availableVouchers;
  final VoucherModel? selectedVoucher;
  final ValueChanged<VoucherModel?> onVoucherChanged;

  @override
  State<VoucherField> createState() => _VoucherFieldState();
}

class _VoucherFieldState extends State<VoucherField> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _applyManualCode() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    // Cek apakah ada di daftar voucher pelanggan
    final match = widget.availableVouchers.where(
      (v) => v.voucherCode.toUpperCase() == code && !v.isUsed,
    );

    if (match.isNotEmpty) {
      widget.onVoucherChanged(match.first);
      _codeController.clear();
    } else {
      // Buat instance voucher ad-hoc bila kode valid dari kupon fisik/promo kasir
      final adHoc = VoucherModel(
        id: 0,
        voucherCode: code,
        rewardId: 0,
        title: 'Voucher $code',
        discountAmount: 0, // Akan dikalkulasi trigger backend
        isUsed: false,
      );
      widget.onVoucherChanged(adHoc);
      _codeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    final hasSelected = widget.selectedVoucher != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.stepVoucher,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (hasSelected)
                TextButton(
                  onPressed: () => widget.onVoucherChanged(null),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.danger,
                  ),
                  child: Text(isEn ? 'Remove' : 'Batal Pakai', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasSelected)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppTheme.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.selectedVoucher!.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${isEn ? 'Code' : 'Kode'}: ${widget.selectedVoucher!.voucherCode}'
                          '${widget.selectedVoucher!.discountAmount > 0 ? ' • ${isEn ? 'Save' : 'Hemat'} ${Formatters.rupiah(widget.selectedVoucher!.discountAmount)}' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 18),
                ],
              ),
            )
          else ...[
            // Input manual
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    // Batasi input voucher_code ke 30 karakter sesuai kolom varchar(30).
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(30),
                    ],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.typeVoucherHint,
                      prefixIcon: const Icon(Icons.discount_outlined, size: 18, color: AppTheme.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _applyManualCode(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyManualCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(l10n.applyVoucher, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            // Daftar voucher aktif milik pelanggan (jika ada)
            if (widget.availableVouchers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                isEn ? 'Customer Active Vouchers:' : 'Voucher Aktif Milik Pelanggan:',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: widget.availableVouchers.where((v) => !v.isUsed).map((v) {
                  return InkWell(
                    onTap: () => widget.onVoucherChanged(v),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.loyalty_rounded, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${v.title} (${Formatters.rupiah(v.discountAmount)})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
