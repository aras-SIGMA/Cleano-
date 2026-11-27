import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/locale_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/profile_avatar_picker.dart';
import '../../widgets/profile_menu_tile.dart';
import 'kasir_profile_sheets.dart';

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
    final updated = await pickAndUploadAvatar(
      context: context,
      authService: widget.authService,
      onUploadingChanged: (v) {
        if (mounted) setState(() => _isUploadingAvatar = v);
      },
    );
    if (!mounted || updated == null) return;
    setState(() => _user = updated);
    widget.onUserUpdated?.call(updated);
  }

  void _showChangePasswordSheet() {
    showChangePasswordBottomSheet(
      context: context,
      subtitle: context.l10n.changePasswordSubtitleKasir,
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
                _buildHeroProfileCard(user),
                const SizedBox(height: 16),
                _buildShiftQuickStats(),
                const SizedBox(height: 20),
                ProfileSectionHeader(context.l10n.sectionAccountSecurity),
                const SizedBox(height: 8),
                _buildAccountSecurityCard(user),
                const SizedBox(height: 20),
                ProfileSectionHeader(context.l10n.sectionHardwarePos),
                const SizedBox(height: 8),
                _buildHardwareSettingsCard(),
                const SizedBox(height: 20),
                ProfileSectionHeader(context.l10n.sectionSopSupport),
                const SizedBox(height: 8),
                _buildSopAndSupportCard(),
                const SizedBox(height: 20),
                ProfileSectionHeader(context.l10n.sectionSystemApp),
                const SizedBox(height: 8),
                _buildSystemInfoCard(),
                const SizedBox(height: 24),
                ProfileLogoutButton(
                  label: context.l10n.kasirCloseShiftLogout,
                  onTap: widget.onLogout,
                ),
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
              ProfileAvatarPicker(
                avatarUrl: user?.avatarUrl,
                fallbackInitial: initial,
                isUploading: _isUploadingAvatar,
                showOnlineDot: true,
                size: 64,
                onTap: _handlePickAvatar,
              ),
              const SizedBox(width: 16),
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
                      ),
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

  Widget _buildAccountSecurityCard(UserModel? user) {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          ProfileMenuTile(
            icon: Icons.mail_outline_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.registeredEmail,
            subtitle: user?.email.isNotEmpty == true ? user!.email : 'kasir@cleano.id',
            showChevron: false,
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.phone_outlined,
            iconColor: AppTheme.primary,
            title: context.l10n.whatsappNumber,
            subtitle: user?.phone.isNotEmpty == true ? user!.phone : '0812-3456-7890',
            showChevron: false,
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppTheme.warning,
            title: context.l10n.changePassword,
            subtitle: context.l10n.changePasswordSub,
            onTap: _showChangePasswordSheet,
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
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
          ProfileMenuTile(
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
                  onPressed: () => showKasirTestReceiptDialog(context, _user ?? widget.user),
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
                  onChanged: (val) => setState(() => _thermalPrinterConnected = val),
                ),
              ],
            ),
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.volume_up_rounded,
            iconColor: AppTheme.success,
            title: context.l10n.soundNotifTitle,
            subtitle: context.l10n.soundNotifSubtitle,
            trailing: Switch.adaptive(
              value: _soundNotification,
              activeThumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary.withValues(alpha: 0.38),
              onChanged: (val) => setState(() => _soundNotification = val),
            ),
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
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
          const ProfileTileDivider(),
          ProfileMenuTile(
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
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          ProfileMenuTile(
            icon: Icons.menu_book_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.sopTitle,
            subtitle: context.l10n.sopSubtitle,
            onTap: () => showKasirSopGuideSheet(context),
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.support_agent_rounded,
            iconColor: AppTheme.warning,
            title: context.l10n.supervisorTitle,
            subtitle: context.l10n.supervisorSubtitle,
            onTap: () => showKasirSupervisorSheet(context),
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.shield_outlined,
            iconColor: AppTheme.success,
            title: context.l10n.termsPrivacyTitle,
            subtitle: context.l10n.termsPrivacySubtitle,
            onTap: () => showKasirPrivacyDialog(context),
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
}
