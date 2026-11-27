import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';

/// Helper aman pembaca terjemahan BuildContext dengan fallback bahasa Indonesia.
extension CleanoL10n on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(LocaleService.instance.locale.value);
}

/// Menampilkan modal bottom-sheet pemilih bahasa sistem (Indonesia / English).
Future<void> showLanguagePickerSheet(BuildContext context) {
  final l10n = context.l10n;
  final currentCode = LocaleService.instance.locale.value.languageCode;

  return showModalBottomSheet<void>(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.language_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.languageSettingTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.languageSettingSubtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LanguageOptionTile(
            code: 'id',
            label: l10n.languageIndonesian,
            badge: 'ID',
            selected: currentCode == 'id',
            onTap: () async {
              await LocaleService.instance.setLocale('id');
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (context.mounted) {
                final updatedL10n = lookupAppLocalizations(const Locale('id'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(updatedL10n.languageChanged(updatedL10n.languageIndonesian)),
                    backgroundColor: AppTheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          _LanguageOptionTile(
            code: 'en',
            label: l10n.languageEnglish,
            badge: 'EN',
            selected: currentCode == 'en',
            onTap: () async {
              await LocaleService.instance.setLocale('en');
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (context.mounted) {
                final updatedL10n = lookupAppLocalizations(const Locale('en'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(updatedL10n.languageChanged(updatedL10n.languageEnglish)),
                    backgroundColor: AppTheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.code,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
