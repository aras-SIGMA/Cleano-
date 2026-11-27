import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'frosted_glass_card.dart';

/// Header teks kecil huruf kapital untuk kelompok pengaturan profil.
class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
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
}

/// Baris menu profil dengan ikon berwarna, judul, subjudul, dan trailing opsional.
class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
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
              trailing!
            else if (showChevron && onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Pemisah antar baris menu pada kartu pengaturan profil.
class ProfileTileDivider extends StatelessWidget {
  const ProfileTileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 16,
      color: AppTheme.border.withValues(alpha: 0.7),
    );
  }
}

/// Kartu tombol keluar akun berwarna merah lembut di bagian bawah profil.
class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FrostedGlassCard(
      onTap: onTap,
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
            label,
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
}
