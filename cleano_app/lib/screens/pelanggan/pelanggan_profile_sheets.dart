import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../services/locale_service.dart';
import '../../widgets/language_picker_sheet.dart';

/// Salin teks ke clipboard lalu tampilkan notifikasi SnackBar singkat.
void copyProfileText(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Menampilkan Kartu Member Digital VIP penuh beserta QR Code berprivasi.
void showFullMemberCardSheet(BuildContext context, UserModel user) {
  final memberCode = user.memberCode.isNotEmpty ? user.memberCode : 'MBR-0001';
  final tier = user.tier.toLowerCase();
  final (cardGradients, tierBadgeBg, tierBadgeFg) = switch (tier) {
    'platinum' => (
        [const Color(0xFF1E1B4B), const Color(0xFF3730A3), const Color(0xFF4F46E5)],
        const Color(0xFFEEF2FF),
        const Color(0xFF312E81),
      ),
    'gold' => (
        [const Color(0xFF78350F), const Color(0xFFB45309), const Color(0xFFD97706)],
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
      ),
    _ => (
        [const Color(0xFF1E293B), const Color(0xFF334155), const Color(0xFF475569)],
        const Color(0xFFF1F5F9),
        const Color(0xFF334155),
      ),
  };

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ctx.l10n.digitalMemberCardTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: cardGradients,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: cardGradients.first.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_laundry_service_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'CLEANO PASS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tierBadgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.tier.toUpperCase(),
                        style: TextStyle(
                          color: tierBadgeFg,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: memberCode,
                    version: QrVersions.auto,
                    size: 160,
                    semanticsLabel: 'QR Code $memberCode',
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => copyProfileText(context, memberCode, context.l10n.memberCodeCopied(memberCode)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          memberCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No. WA: ${Formatters.sensorTelepon(user.phone)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showShareMemberCardSheet(context, user);
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(ctx.l10n.send),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  child: Text(ctx.l10n.close, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Menampilkan modal berbagi kartu member ke kurir atau keluarga.
void showShareMemberCardSheet(BuildContext context, UserModel user) {
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';
  final memberCode = user.memberCode.isNotEmpty ? user.memberCode : 'MBR-0001';
  final shareMessage = isEn
      ? '🧺 *CLEANO LAUNDRY — LAUNDRY DROP-OFF*\n\n'
          'Hi! Please help drop off my laundry at Cleano:\n'
          '• *Member Name:* ${user.name}\n'
          '• *Member Code:* $memberCode\n'
          '• *Tier:* ${user.tier} Member\n'
          '• *Contact No.:* ${Formatters.sensorTelepon(user.phone)}\n\n'
          'Just show this member code *$memberCode* to the Cleano cashier during drop-off so points and orders are recorded directly to my account. Thank you! 🙏'
      : '🧺 *CLEANO LAUNDRY — TITIP CUCIAN*\n\n'
          'Halo! Tolong titip cucian saya di Cleano ya:\n'
          '• *Nama Member:* ${user.name}\n'
          '• *Kode Member:* $memberCode\n'
          '• *Tier:* ${user.tier} Member\n'
          '• *No. Kontak:* ${Formatters.sensorTelepon(user.phone)}\n\n'
          'Cukup tunjukkan kode member *$memberCode* ini kepada kasir Cleano saat drop-off pakaian agar poin dan pesanan tercatat langsung di akun saya. Terima kasih! 🙏';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
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
                child: const Icon(Icons.share_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctx.l10n.shareModalTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      ctx.l10n.shareModalSubtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ctx.l10n.shareModalBenefit,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ShareOptionTile(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF25D366),
            title: ctx.l10n.shareWhatsappFormat,
            subtitle: ctx.l10n.shareWhatsappSubtitle,
            onTap: () {
              Navigator.pop(ctx);
              copyProfileText(context, shareMessage, context.l10n.shareMessageCopied);
            },
          ),
          const SizedBox(height: 10),
          _ShareOptionTile(
            icon: Icons.copy_rounded,
            iconColor: AppTheme.primary,
            title: ctx.l10n.shareCodeOnly(memberCode),
            subtitle: ctx.l10n.shareCodeOnlySubtitle,
            onTap: () {
              Navigator.pop(ctx);
              copyProfileText(context, memberCode, context.l10n.memberCodeCopied(memberCode));
            },
          ),
          const SizedBox(height: 10),
          _ShareOptionTile(
            icon: Icons.qr_code_2_rounded,
            iconColor: AppTheme.deepAzure,
            title: ctx.l10n.shareQrScreenshot,
            subtitle: ctx.l10n.shareQrScreenshotSubtitle,
            onTap: () {
              Navigator.pop(ctx);
              showFullMemberCardSheet(context, user);
            },
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

/// Menampilkan dialog panduan pengumpulan poin dan penukaran hadiah.
void showPelangganPointsGuideDialog(BuildContext context) {
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEn ? 'Cleano Points Guide' : 'Panduan Poin Cleano'),
      content: Text(
        isEn
            ? '1. Every transaction in multiples of Rp 10,000 earns 1 point.\n'
                '2. Laundry ≥ 5 kg or Express service earns 2x bonus points!\n'
                '3. Collect 100 points for Gold, 300 points for Platinum.\n'
                '4. Redeem points for discount vouchers in the Rewards menu.'
            : '1. Setiap transaksi kelipatan Rp 10.000 mendapat 1 poin.\n'
                '2. Cucian ≥ 5 kg atau layanan Express mendapat bonus 2x poin!\n'
                '3. Kumpulkan 100 poin untuk Gold, 300 poin untuk Platinum.\n'
                '4. Tukarkan poin dengan voucher diskon di menu Hadiah.',
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.understood)),
      ],
    ),
  );
}

/// Menampilkan dialog kebijakan privasi data pelanggan Cleano.
void showPelangganPrivacyDialog(BuildContext context) {
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEn ? 'Customer Privacy' : 'Privasi Pelanggan'),
      content: Text(
        isEn
            ? 'Cleano is fully committed to protecting your data privacy:\n\n'
                '• Phone numbers are masked on physical and QR cards.\n'
                '• Email is never displayed on the member card.\n'
                '• Clothing photos are only used as drop-off proof for laundry integrity.'
            : 'Cleano berkomitmen penuh menjaga privasi data Anda:\n\n'
                '• Nomor telepon disensor pada kartu fisik dan kartu QR.\n'
                '• Email tidak pernah ditampilkan pada kartu member.\n'
                '• Foto pakaian hanya digunakan sebagai bukti drop-off demi integritas cucian.',
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.close)),
      ],
    ),
  );
}

class _ShareOptionTile extends StatelessWidget {
  const _ShareOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
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
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
