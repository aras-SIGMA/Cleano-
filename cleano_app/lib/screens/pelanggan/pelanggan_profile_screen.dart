import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/locale_service.dart';
import '../../services/session_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/profile_avatar_picker.dart';
import '../../widgets/profile_menu_tile.dart';
import 'pelanggan_profile_sheets.dart';

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
    final updated = await pickAndUploadAvatar(
      context: context,
      authService: _authService,
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
                  _buildHeroCustomerCard(user),
                  const SizedBox(height: 16),
                  _buildDigitalPassSection(user),
                  const SizedBox(height: 20),
                  ProfileSectionHeader(context.l10n.sectionAccountSecurity),
                  const SizedBox(height: 8),
                  _buildAccountSecurityCard(user),
                  const SizedBox(height: 20),
                  ProfileSectionHeader(context.l10n.sectionServicePrefs),
                  const SizedBox(height: 8),
                  _buildServicePreferencesCard(),
                  const SizedBox(height: 20),
                  ProfileSectionHeader(context.l10n.sectionHelpGuide),
                  const SizedBox(height: 8),
                  _buildHelpAndSupportCard(),
                  const SizedBox(height: 24),
                  ProfileLogoutButton(
                    label: context.l10n.pelangganLogoutBtn,
                    onTap: widget.onLogout,
                  ),
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
                      ),
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
          InkWell(
            onTap: () {
              if (user != null) showFullMemberCardSheet(context, user);
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (user != null) showFullMemberCardSheet(context, user);
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
                    if (user != null) showShareMemberCardSheet(context, user);
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
            subtitle: user?.email.isNotEmpty == true ? user!.email : 'pelanggan@cleano.id',
            showChevron: false,
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.phone_outlined,
            iconColor: AppTheme.primary,
            title: context.l10n.activeWhatsappNumber,
            subtitle: user?.phone.isNotEmpty == true ? user!.phone : '0812-3456-7890',
            showChevron: false,
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
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
          ProfileMenuTile(
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
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.notifications_active_outlined,
            iconColor: const Color(0xFF25D366),
            title: context.l10n.waNotifTitle,
            subtitle: context.l10n.waNotifSubtitle,
            trailing: Switch.adaptive(
              value: _waNotificationEnabled,
              activeThumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary.withValues(alpha: 0.38),
              onChanged: (val) => setState(() => _waNotificationEnabled = val),
            ),
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

  Widget _buildHelpAndSupportCard() {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          ProfileMenuTile(
            icon: Icons.headset_mic_rounded,
            iconColor: const Color(0xFF25D366),
            title: context.l10n.csWhatsappTitle,
            subtitle: context.l10n.csWhatsappSubtitle,
            onTap: () => copyProfileText(context, '081299887766', context.l10n.csPhoneCopied),
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.primary,
            title: context.l10n.pointsGuideTitle,
            subtitle: context.l10n.pointsGuideSubtitle,
            onTap: () => showPelangganPointsGuideDialog(context),
          ),
          const ProfileTileDivider(),
          ProfileMenuTile(
            icon: Icons.shield_outlined,
            iconColor: AppTheme.success,
            title: context.l10n.privacyTitle,
            subtitle: context.l10n.privacySubtitle,
            onTap: () => showPelangganPrivacyDialog(context),
          ),
        ],
      ),
    );
  }
}
