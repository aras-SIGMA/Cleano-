import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/locale_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/profile_avatar_picker.dart';

/// Layar Profil & Pengaturan Kasir bergaya iOS Frosted Glass.
class KasirProfileScreen extends StatefulWidget {
  const KasirProfileScreen({
    super.key,
    this.user,
    this.onLogout,
    this.onUserUpdated,
    this.authService,
  });

  final UserModel? user;
  final VoidCallback? onLogout;
  final ValueChanged<UserModel>? onUserUpdated;
  final AuthService? authService;

  @override
  State<KasirProfileScreen> createState() => _KasirProfileScreenState();
}

class _KasirProfileScreenState extends State<KasirProfileScreen> {
  UserModel? _user;
  bool _isUploadingAvatar = false;
  bool _soundNotification = true;
  bool _thermalPrinterConnected = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  void didUpdateWidget(KasirProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != null && !identical(widget.user, oldWidget.user)) {
      _user = widget.user;
    }
  }

  Future<void> _handlePickAvatar() async {
    final file = await showAvatarSourceSheet(context);
    if (file == null || !mounted) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final updated = await (widget.authService ?? AuthService.instance).updateAvatar(
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() => _user = updated);
      widget.onUserUpdated?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.avatarUpdated),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.avatarUpdateFailed('$e')),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showTestReceiptDialog() {
    final now = DateTime.now();
    final isEn = LocaleService.instance.locale.value.languageCode == 'en';
    showDialog(
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
                    _receiptRow(isEn ? 'Cashier' : 'Kasir', widget.user?.name ?? (isEn ? 'Cashier Staff' : 'Staf Kasir')),
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

  static Widget _receiptRow(String left, String right) {
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

  void _showChangePasswordSheet() {
    showChangePasswordBottomSheet(
      context: context,
      subtitle: context.l10n.changePasswordSubtitleKasir,
      authService: widget.authService,
    );
  }

  void _showSopGuideSheet() {
    final isEn = LocaleService.instance.locale.value.languageCode == 'en';
    showModalBottomSheet(
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

  void _showSupervisorContactSheet() {
    final isEn = LocaleService.instance.locale.value.languageCode == 'en';
    showModalBottomSheet(
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

  @override
  Widget build(BuildContext context) {
    final user = _user ?? widget.user;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          context.l10n.kasirProfileTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FrostedGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              borderRadius: 20,
              blurSigma: 12,
              onTap: widget.onLogout,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.logout_rounded, size: 15, color: AppTheme.danger),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.logout,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Card Profil Kasir
                _buildHeroProfileCard(user),
                const SizedBox(height: 16),

                // 2. Tiga Chip Metrik Shift & Status Konter
                _buildShiftQuickStats(),
                const SizedBox(height: 20),

                // 3. Seksi 1: Informasi Akun & Keamanan
                _buildSectionHeader(context.l10n.sectionAccountSecurity),
                const SizedBox(height: 8),
                _buildAccountSecurityCard(user),
                const SizedBox(height: 20),

                // 4. Seksi 2: Perangkat & Hardware POS
                _buildSectionHeader(context.l10n.sectionHardwarePos),
                const SizedBox(height: 8),
                _buildHardwareSettingsCard(),
                const SizedBox(height: 20),

                // 5. Seksi 3: Standar Operasional & Bantuan
                _buildSectionHeader(context.l10n.sectionSopSupport),
                const SizedBox(height: 8),
                _buildSopAndSupportCard(),
                const SizedBox(height: 20),

                // 6. Seksi 4: Informasi Sistem & Server
                _buildSectionHeader(context.l10n.sectionSystemApp),
                const SizedBox(height: 8),
                _buildSystemInfoCard(),
                const SizedBox(height: 24),

                // 7. Tombol Tutup Shift & Keluar Akun
                _buildLogoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroProfileCard(UserModel? user) {
    final isEn = LocaleService.instance.locale.value.languageCode == 'en';
    final staffName = user?.name.isNotEmpty == true ? user!.name : (isEn ? 'Cleano Cashier' : 'Kasir Cleano');
    final memberCode = user?.memberCode.isNotEmpty == true ? user!.memberCode : 'STF-KASIR';
    final initial = staffName.isNotEmpty ? staffName[0].toUpperCase() : 'K';

    return FrostedGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            children: [
              // Avatar dengan Badge Status Online & Upload Foto Profil
              ProfileAvatarPicker(
                avatarUrl: user?.avatarUrl,
                fallbackInitial: initial,
                isUploading: _isUploadingAvatar,
                showOnlineDot: true,
                size: 64,
                onTap: _handlePickAvatar,
              ),
              const SizedBox(width: 16),
              // Nama & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.l10n.staffRoleBadge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          memberCode,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Outlet Info Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.outletCenterName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.l10n.onlineBadge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _quickStatItem(
            icon: Icons.schedule_rounded,
            title: context.l10n.shiftTitle,
            value: context.l10n.shiftMorningValue,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickStatItem(
            icon: Icons.point_of_sale_rounded,
            title: context.l10n.counterPosTitle,
            value: context.l10n.counterReadyValue,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickStatItem(
            icon: Icons.sync_rounded,
            title: context.l10n.syncTitle,
            value: context.l10n.syncRealtimeValue,
            color: AppTheme.deepAzure,
          ),
        ),
      ],
    );
  }

  Widget _quickStatItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return FrostedGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildAccountSecurityCard(UserModel? user) {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.mail_outline_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.registeredEmail,
            subtitle: user?.email.isNotEmpty == true ? user!.email : 'kasir@cleano.id',
            showChevron: false,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.phone_outlined,
            iconColor: AppTheme.primary,
            title: context.l10n.whatsappNumber,
            subtitle: user?.phone.isNotEmpty == true ? user!.phone : '0812-3456-7890',
            showChevron: false,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppTheme.warning,
            title: context.l10n.changePassword,
            subtitle: context.l10n.changePasswordSub,
            onTap: _showChangePasswordSheet,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.pin_rounded,
            iconColor: AppTheme.deepAzure,
            title: context.l10n.authPinTitle,
            subtitle: context.l10n.authPinSubtitle,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.authPinInfo),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareSettingsCard() {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.print_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.thermalPrinterTitle,
            subtitle: _thermalPrinterConnected
                ? context.l10n.printerConnected
                : context.l10n.printerDisconnected,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _showTestReceiptDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    context.l10n.testPrint,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _thermalPrinterConnected,
                  activeThumbColor: AppTheme.primary,
                  activeTrackColor: AppTheme.primary.withValues(alpha: 0.38),
                  onChanged: (val) {
                    setState(() => _thermalPrinterConnected = val);
                  },
                ),
              ],
            ),
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.volume_up_rounded,
            iconColor: AppTheme.success,
            title: context.l10n.soundNotifTitle,
            subtitle: context.l10n.soundNotifSubtitle,
            trailing: Switch.adaptive(
              value: _soundNotification,
              activeThumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary.withValues(alpha: 0.38),
              onChanged: (val) {
                setState(() => _soundNotification = val);
              },
            ),
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: AppTheme.deepAzure,
            title: context.l10n.posScannerTitle,
            subtitle: context.l10n.posScannerSubtitle,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.posScannerInfo),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.language_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.languageSettingTitle,
            subtitle: LocaleService.instance.locale.value.languageCode == 'en'
                ? context.l10n.languageEnglish
                : context.l10n.languageIndonesian,
            onTap: () => showLanguagePickerSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSopAndSupportCard() {
    final isEn = LocaleService.instance.locale.value.languageCode == 'en';
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.menu_book_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.sopTitle,
            subtitle: context.l10n.sopSubtitle,
            onTap: _showSopGuideSheet,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.support_agent_rounded,
            iconColor: AppTheme.warning,
            title: context.l10n.supervisorTitle,
            subtitle: context.l10n.supervisorSubtitle,
            onTap: _showSupervisorContactSheet,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.shield_outlined,
            iconColor: AppTheme.success,
            title: context.l10n.termsPrivacyTitle,
            subtitle: context.l10n.termsPrivacySubtitle,
            onTap: () {
              showDialog(
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard() {
    final isEn = LocaleService.instance.locale.value.languageCode == 'en';
    return FrostedGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      child: Column(
        children: [
          _systemRow(isEn ? 'App Version' : 'Versi Aplikasi', 'Cleano POS v1.0.0+1 (Build 2026.11)'),
          const SizedBox(height: 8),
          _systemRow(isEn ? 'Server Connection' : 'Koneksi Server', 'Aiven Cloud MySQL 8 (TLS 1.3)'),
          const SizedBox(height: 8),
          _systemRow(isEn ? 'Payment Gateway' : 'Gateway Pembayaran', isEn ? 'Midtrans Snap Sandbox Active' : 'Midtrans Snap Sandbox Aktif'),
          const SizedBox(height: 8),
          _systemRow(isEn ? 'Proof Storage' : 'Penyimpanan Bukti', 'Cloudinary CDN Cloud Storage'),
        ],
      ),
    );
  }

  static Widget _systemRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return FrostedGlassCard(
      onTap: widget.onLogout,
      borderRadius: 18,
      backgroundColor: const Color(0xFFFEF2F2),
      border: Border.all(color: const Color(0xFFFCA5A5)),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 20),
          const SizedBox(width: 8),
          Text(
            context.l10n.kasirCloseShiftLogout,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (showChevron && onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _tileDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 16,
      color: AppTheme.border.withValues(alpha: 0.7),
    );
  }
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
