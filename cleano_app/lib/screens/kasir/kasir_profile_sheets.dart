import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../services/locale_service.dart';
import '../../widgets/language_picker_sheet.dart';

/// Menampilkan dialog simulasi struk thermal 58mm untuk kasir.
void showKasirTestReceiptDialog(BuildContext context, UserModel? user) {
  final now = DateTime.now();
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.print_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ctx.l10n.simReceiptTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  const Text(
                    'CLEANO SMART LAUNDRY',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEn ? 'Outlet 01 — Main Branch' : 'Outlet 01 — Cabang Utama',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const Text(
                    'Jl. Sukajadi No. 42, Bandung',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                  const Divider(height: 20, thickness: 1),
                  _receiptRow(isEn ? 'Print Time' : 'Waktu Cetak', '${Formatters.tanggal(now)} ${Formatters.jam(now)}'),
                  _receiptRow(isEn ? 'Cashier' : 'Kasir', user?.name ?? (isEn ? 'Cashier Staff' : 'Staf Kasir')),
                  _receiptRow(isEn ? 'Transaction Code' : 'Kode Transaksi', 'CLN-TEST-0001'),
                  _receiptRow('Status', isEn ? 'THERMAL 58mm TEST' : 'UJI COBA THERMAL 58mm'),
                  const Divider(height: 20, thickness: 1),
                  _receiptRow(isEn ? 'Full Wash (3.5 kg)' : 'Cuci Komplit (3.5 kg)', 'Rp 24.500'),
                  _receiptRow(isEn ? 'Voucher Discount' : 'Diskon Voucher', '-Rp 0'),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEn ? 'TOTAL PAID' : 'TOTAL LUNAS', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const Text('Rp 24.500', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1),
                  Text(
                    isEn
                        ? '*** SYSTEM VALIDATION RECEIPT ***\nThank you for your visit'
                        : '*** STRUK VALIDASI SISTEM ***\nTerima kasih atas kunjungan Anda',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.printSentMsg),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.check_rounded),
              label: Text(ctx.l10n.sendToPrinter),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _receiptRow(String left, String right) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          right,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    ),
  );
}

/// Menampilkan bottom-sheet panduan SOP kasir dan estafet mesin.
void showKasirSopGuideSheet(BuildContext context) {
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: AppTheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ctx.l10n.sopTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        isEn
                            ? 'Cleano cleanliness & service standard operating procedures'
                            : 'Standar operasional kebersihan & pelayanan Cleano',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  _SopItem(
                    number: '1',
                    title: isEn ? 'Customer Identification & Drop-Off' : 'Identifikasi Pelanggan & Drop-Off',
                    description: isEn
                        ? 'Scan the Member QR or search the customer phone number. Always take a clear clothing photo as drop-off proof before washing begins.'
                        : 'Pindai QR Member atau cari nomor HP pelanggan. Pastikan mengambil foto pakaian fisik yang jelas sebagai bukti drop-off sebelum cucian masuk proses pencucian.',
                    icon: Icons.qr_code_scanner_rounded,
                  ),
                  _SopItem(
                    number: '2',
                    title: isEn ? 'Weighing & Pocket Check' : 'Penimbangan & Pengecekan Kantong',
                    description: isEn
                        ? 'Weigh laundry accurately (2 decimal digits). Always check pockets for hard objects, cash, or valuables before starting the wash.'
                        : 'Timbang cucian secara presisi (desimal 2 digit). Selalu cek saku pakaian dari benda keras, uang, atau barang berharga sebelum memulai cucian.',
                    icon: Icons.scale_rounded,
                  ),
                  _SopItem(
                    number: '3',
                    title: isEn ? 'Automatic Machine Relay (FIFO)' : 'Estafet Mesin Cuci Otomatis (FIFO)',
                    description: isEn
                        ? 'When laundry is marked "Ready for Pickup", the system prompts a relay confirmation for the next queued order. Confirm promptly so machines stay utilized.'
                        : 'Saat cucian ditandai "Siap Diambil", sistem memunculkan konfirmasi estafet untuk cucian antrean berikutnya. Konfirmasi segera agar mesin tidak menganggur.',
                    icon: Icons.sync_alt_rounded,
                  ),
                  _SopItem(
                    number: '4',
                    title: isEn ? 'Pickup & Payment Verification' : 'Pengambilan & Verifikasi Pembayaran',
                    description: isEn
                        ? 'Ensure the order status is "PAID" before handover. For Cash on Pickup, collect payment before completing the order in the app.'
                        : 'Pastikan pesanan berstatus "LUNAS" sebelum diserahkan. Jika pembayaran Tunai saat ambil, terima uang sebelum menyelesaikan pesanan di aplikasi.',
                    icon: Icons.verified_user_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Menampilkan bottom-sheet kontak supervisor dan tim dukungan.
void showKasirSupervisorSheet(BuildContext context) {
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.support_agent_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Help & Supervisor Contacts' : 'Bantuan & Kontak Supervisor',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      isEn
                          ? 'Contact the outlet person-in-charge for operational issues'
                          : 'Hubungi penanggung jawab outlet untuk kendala operasional',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ContactCard(
            title: isEn ? 'Hendra Saputra (Outlet Supervisor)' : 'Hendra Saputra (Supervisor Outlet)',
            subtitle: isEn ? 'Shift & Operations Person-in-Charge' : 'Penanggung Jawab Shift & Operasional',
            phone: '0812-8899-7711',
            icon: Icons.person_pin_rounded,
          ),
          const SizedBox(height: 10),
          _ContactCard(
            title: isEn ? 'Cleano IT & Support Team' : 'Tim IT & Support Cleano',
            subtitle: isEn ? 'POS System, Printer & Server Issues' : 'Kendala Sistem POS, Printer & Server',
            phone: '0811-2233-4455',
            icon: Icons.headset_mic_rounded,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(ctx.l10n.close),
          ),
        ],
      ),
    ),
  );
}

/// Menampilkan dialog kebijakan privasi dan ketentuan layanan untuk kasir.
void showKasirPrivacyDialog(BuildContext context) {
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(ctx.l10n.privacyTermsDialogTitle),
      content: Text(
        isEn
            ? 'Cleano protects customer data privacy:\n\n'
                '1. Phone numbers are masked for security.\n'
                '2. Customer emails are never shared carelessly.\n'
                '3. Drop-off photos are only used as physical condition proof.\n'
                '4. All transactions are securely recorded with database audit.'
            : 'Cleano menjaga privasi data pelanggan:\n\n'
                '1. Nomor telepon disensor untuk keamanan.\n'
                '2. Email pelanggan tidak dibagikan sembarangan.\n'
                '3. Foto drop-off hanya digunakan sebagai bukti kondisi fisik pakaian.\n'
                '4. Seluruh transaksi terekam aman dengan audit database.',
        style: const TextStyle(fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.l10n.close),
        ),
      ],
    ),
  );
}

class _SopItem extends StatelessWidget {
  const _SopItem({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.title,
    required this.subtitle,
    required this.phone,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String phone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
