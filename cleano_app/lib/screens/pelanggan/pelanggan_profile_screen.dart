import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/locale_service.dart';
import '../../services/session_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/profile_avatar_picker.dart';

/// Layar Profil & Pengaturan Pelanggan dengan kartu member dan preferensi.
class PelangganProfileScreen extends StatefulWidget {
  const PelangganProfileScreen({
    super.key,
    this.user,
    this.onLogout,
    this.onNavigateToRewards,
    this.onUserUpdated,
    this.authService,
    this.sessionService,
  });

  final UserModel? user;
  final VoidCallback? onLogout;
  final VoidCallback? onNavigateToRewards;
  final ValueChanged<UserModel>? onUserUpdated;
  final AuthService? authService;
  final SessionService? sessionService;

  @override
  State<PelangganProfileScreen> createState() => _PelangganProfileScreenState();
}

class _PelangganProfileScreenState extends State<PelangganProfileScreen> {
  AuthService get _authService => widget.authService ?? AuthService.instance;
  SessionService get _sessionService => widget.sessionService ?? SessionService.instance;

  UserModel? _user;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  bool _waNotificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    if (_user == null) _loadUserData();
  }

  @override
  void didUpdateWidget(PelangganProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != null && !identical(widget.user, oldWidget.user)) {
      _user = widget.user;
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final cached = await _sessionService.getUser();
    if (mounted && cached != null) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    try {
      final fresh = await _authService.getMe();
      if (mounted && fresh != null) {
        setState(() {
          _user = fresh;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePickAvatar() async {
    final file = await showAvatarSourceSheet(context);
    if (file == null || !mounted) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final updated = await _authService.updateAvatar(
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

  /// Menampilkan Kartu Member Digital VIP Penuh beserta QR Code
  void _showFullMemberCardSheet(UserModel user) {
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

    showModalBottomSheet(
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

            // Kartu Member VIP
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

                  // QR Code Box
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

                  // Teks Member Code di Bawah QR
                  GestureDetector(
                    onTap: () => _copyToClipboard(memberCode, context.l10n.memberCodeCopied(memberCode)),
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

                  // Nama dan Nomor HP Tersensor (Privasi Tinggi: Tanpa Email!)
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

            // Tombol Aksi Cepat
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showShareMemberCardSheet(user);
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

  /// Menampilkan Modal Berbagi Kartu Member ke Kurir / Keluarga
  void _showShareMemberCardSheet(UserModel user) {
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

    showModalBottomSheet(
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

            // Penjelasan Manfaat
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

            // Opsi 1: Salin Format Pesan Chat Lengkap
            _shareOptionTile(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF25D366),
              title: ctx.l10n.shareWhatsappFormat,
              subtitle: ctx.l10n.shareWhatsappSubtitle,
              onTap: () {
                Navigator.pop(ctx);
                _copyToClipboard(shareMessage, context.l10n.shareMessageCopied);
              },
            ),
            const SizedBox(height: 10),

            // Opsi 2: Salin Kode Member Saja
            _shareOptionTile(
              icon: Icons.copy_rounded,
              iconColor: AppTheme.primary,
              title: ctx.l10n.shareCodeOnly(memberCode),
              subtitle: ctx.l10n.shareCodeOnlySubtitle,
              onTap: () {
                Navigator.pop(ctx);
                _copyToClipboard(memberCode, context.l10n.memberCodeCopied(memberCode));
              },
            ),
            const SizedBox(height: 10),

            // Opsi 3: Tampilkan Gambar Kartu QR
            _shareOptionTile(
              icon: Icons.qr_code_2_rounded,
              iconColor: AppTheme.deepAzure,
              title: ctx.l10n.shareQrScreenshot,
              subtitle: ctx.l10n.shareQrScreenshotSubtitle,
              onTap: () {
                Navigator.pop(ctx);
                _showFullMemberCardSheet(user);
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

  Widget _shareOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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

  void _copyToClipboard(String text, String message) {
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

  void _showChangePasswordSheet() {
    showChangePasswordBottomSheet(
      context: context,
      subtitle: context.l10n.changePasswordSubtitlePelanggan,
      authService: widget.authService,
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
          context.l10n.pelangganProfileTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          if (widget.onLogout != null)
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
          if (_isLoading && user == null)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Profile Card
                  _buildHeroCustomerCard(user),
                  const SizedBox(height: 16),

                  // 2. Kartu Akses Member Digital & Opsi QR / Kirim
                  _buildDigitalPassSection(user),
                  const SizedBox(height: 20),

                  // 3. Seksi Informasi Akun & Keamanan
                  _buildSectionHeader(context.l10n.sectionAccountSecurity),
                  const SizedBox(height: 8),
                  _buildAccountSecurityCard(user),
                  const SizedBox(height: 20),

                  // 4. Seksi Preferensi Layanan & Notifikasi
                  _buildSectionHeader(context.l10n.sectionServicePrefs),
                  const SizedBox(height: 8),
                  _buildServicePreferencesCard(),
                  const SizedBox(height: 20),

                  // 5. Seksi Bantuan & Layanan Pelanggan
                  _buildSectionHeader(context.l10n.sectionHelpGuide),
                  const SizedBox(height: 8),
                  _buildHelpAndSupportCard(),
                  const SizedBox(height: 24),

                  // 6. Tombol Logout
                  _buildLogoutButton(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroCustomerCard(UserModel? user) {
    final isEn = LocaleService.instance.locale.value.languageCode == 'en';
    final name = user?.name.isNotEmpty == true ? user!.name : (isEn ? 'Cleano Customer' : 'Pelanggan Cleano');
    final tier = user?.tier.isNotEmpty == true ? user!.tier : 'Silver';
    final points = user?.points ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    final (tierColor, nextTierText, progress) = switch (tier.toLowerCase()) {
      'platinum' => (const Color(0xFF4F46E5), context.l10n.highestTierVip, 1.0),
      'gold' => (
          AppTheme.warning,
          context.l10n.pointsToPlatinum(300 - points > 0 ? 300 - points : 0),
          (points / 300).clamp(0.0, 1.0)
        ),
      _ => (
          const Color(0xFF64748B),
          context.l10n.pointsToGold(100 - points > 0 ? 100 - points : 0),
          (points / 100).clamp(0.0, 1.0)
        ),
    };

    return FrostedGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            children: [
              ProfileAvatarPicker(
                avatarUrl: user?.avatarUrl,
                fallbackInitial: initial,
                isUploading: _isUploadingAvatar,
                showOnlineDot: false,
                size: 62,
                onTap: _handlePickAvatar,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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
                            color: tierColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$tier Member'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: tierColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user?.memberCode ?? 'MBR-0001',
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

          // Poin & Progress Tier Strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          isEn ? '$points Loyalty Points' : '$points Poin Loyalti',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (widget.onNavigateToRewards != null)
                      GestureDetector(
                        onTap: widget.onNavigateToRewards,
                        child: Text(
                          context.l10n.redeemRewardsLink,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFCBD5E1),
                    valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nextTierText,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bagian Kartu Akses Member Digital dengan opsi QR dan bagikan.
  Widget _buildDigitalPassSection(UserModel? user) {
    final memberCode = user?.memberCode.isNotEmpty == true ? user!.memberCode : 'MBR-0001';
    final tier = user?.tier ?? 'Silver';

    return FrostedGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.digitalPassTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      context.l10n.digitalPassSubtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini Wallet Pass Preview
          InkWell(
            onTap: () {
              if (user != null) _showFullMemberCardSheet(user);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0F172A),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$tier Member • $memberCode'.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.tapToShowQr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.fullscreen_rounded, color: Colors.white70, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Dua Tombol Aksi: Tampilkan QR & Kirim
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (user != null) _showFullMemberCardSheet(user);
                  },
                  icon: const Icon(Icons.qr_code_rounded, size: 17),
                  label: Text(context.l10n.openQrCard),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (user != null) _showShareMemberCardSheet(user);
                  },
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: Text(context.l10n.send),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
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
            subtitle: user?.email.isNotEmpty == true ? user!.email : 'pelanggan@cleano.id',
            showChevron: false,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.phone_outlined,
            iconColor: AppTheme.primary,
            title: context.l10n.activeWhatsappNumber,
            subtitle: user?.phone.isNotEmpty == true ? user!.phone : '0812-3456-7890',
            showChevron: false,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppTheme.warning,
            title: context.l10n.updatePassword,
            subtitle: context.l10n.changePasswordSubtitlePelanggan,
            onTap: _showChangePasswordSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildServicePreferencesCard() {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.storefront_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.favOutletTitle,
            subtitle: context.l10n.favOutletSubtitle,
            showChevron: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.favOutletInfo),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.notifications_active_outlined,
            iconColor: const Color(0xFF25D366),
            title: context.l10n.waNotifTitle,
            subtitle: context.l10n.waNotifSubtitle,
            trailing: Switch.adaptive(
              value: _waNotificationEnabled,
              activeThumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary.withValues(alpha: 0.38),
              onChanged: (val) {
                setState(() => _waNotificationEnabled = val);
              },
            ),
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

  Widget _buildHelpAndSupportCard() {
    final isEn = LocaleService.instance.locale.value.languageCode == 'en';
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.headset_mic_rounded,
            iconColor: const Color(0xFF25D366),
            title: context.l10n.csWhatsappTitle,
            subtitle: context.l10n.csWhatsappSubtitle,
            onTap: () {
              _copyToClipboard('081299887766', context.l10n.csPhoneCopied);
            },
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.pointsGuideTitle,
            subtitle: context.l10n.pointsGuideSubtitle,
            onTap: () {
              showDialog(
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
            },
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.shield_outlined,
            iconColor: AppTheme.success,
            title: context.l10n.privacyTitle,
            subtitle: context.l10n.privacySubtitle,
            onTap: () {
              showDialog(
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
            },
          ),
        ],
      ),
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
            context.l10n.pelangganLogoutBtn,
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
