import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import 'language_picker_sheet.dart';

/// Avatar profil bulat dengan foto jaringan, inisial fallback, dan tombol kamera.
class ProfileAvatarPicker extends StatelessWidget {
  const ProfileAvatarPicker({
    super.key,
    required this.fallbackInitial,
    required this.onTap,
    this.avatarUrl,
    this.isUploading = false,
    this.showOnlineDot = false,
    this.size = 64,
  });

  final String? avatarUrl;
  final String fallbackInitial;
  final bool isUploading;
  final bool showOnlineDot;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Semantics(
      button: true,
      label: context.l10n.changeProfilePhoto,
      child: InkWell(
        onTap: isUploading ? null : onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          children: [
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.deepAzure],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33007FFF),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: hasUrl
                    ? Image.network(
                        avatarUrl!,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildInitial(),
                      )
                    : _buildInitial(),
              ),
            ),
            if (isUploading)
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (showOnlineDot)
              Positioned(
                left: 2,
                bottom: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.border, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 13,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        fallbackInitial,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Buka modal pemilih sumber foto (Kamera/Galeri) dan kembalikan XFile.
Future<XFile?> showAvatarSourceSheet(
  BuildContext context, {
  ImagePicker? picker,
}) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
          Text(
            l10n.changeProfilePhoto,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFFF8FAFC),
            leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
            title: Text(
              l10n.takeFromCamera,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFFF8FAFC),
            leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
            title: Text(
              l10n.chooseFromGallery,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  if (source == null) return null;
  final activePicker = picker ?? ImagePicker();
  return activePicker.pickImage(
    source: source,
    imageQuality: 80,
    maxWidth: 800,
    maxHeight: 800,
  );
}
