import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/reward_model.dart';
import '../../../widgets/frosted_glass_card.dart';
import '../../../widgets/state_view.dart';

/// Tab 3 master data: katalog kupon loyalti beserta aksi edit dan toggle aktif.
class RewardsTab extends StatelessWidget {
  const RewardsTab({
    super.key,
    required this.rewards,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onEdit,
    required this.onToggleActive,
  });

  final List<RewardModel> rewards;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(RewardModel) onEdit;
  final void Function(RewardModel) onToggleActive;

  @override
  Widget build(BuildContext context) {
    if (isLoading && rewards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && rewards.isEmpty) {
      return StateErrorView(message: error!, onRetry: onRefresh);
    }

    if (rewards.isEmpty) {
      return const StateEmptyView(message: 'Belum ada katalog promo reward loyalti.');
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        itemCount: rewards.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _RewardCard(
          reward: rewards[index],
          onEdit: onEdit,
          onToggleActive: onToggleActive,
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.onEdit, required this.onToggleActive});

  final RewardModel reward;
  final void Function(RewardModel) onEdit;
  final void Function(RewardModel) onToggleActive;

  @override
  Widget build(BuildContext context) {
    return FrostedGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      blurSigma: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  reward.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: reward.isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                    decoration: reward.isActive ? null : TextDecoration.lineThrough,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: reward.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  reward.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: reward.isActive ? const Color(0xFF15803D) : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${reward.pointsRequired} Poin',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Potongan ${Formatters.rupiah(reward.discountAmount)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
            ],
          ),
          if (reward.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reward.description,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => onEdit(reward),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => onToggleActive(reward),
                icon: Icon(
                  reward.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  size: 20,
                  color: reward.isActive ? AppTheme.success : AppTheme.textMuted,
                ),
                label: Text(
                  reward.isActive ? 'Nonaktifkan' : 'Aktifkan',
                  style: TextStyle(
                    fontSize: 12,
                    color: reward.isActive ? AppTheme.danger : AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
