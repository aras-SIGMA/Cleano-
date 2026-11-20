import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/machine_model.dart';
import '../../../widgets/frosted_glass_card.dart';
import '../../../widgets/state_view.dart';

/// Tab 2 master data: daftar unit mesin dan tombol ubah status operasional.
class MachinesTab extends StatelessWidget {
  const MachinesTab({
    super.key,
    required this.machines,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onToggleStatus,
  });

  final List<MachineModel> machines;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(MachineModel) onToggleStatus;

  @override
  Widget build(BuildContext context) {
    if (isLoading && machines.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && machines.isEmpty) {
      return StateErrorView(message: error!, onRetry: onRefresh);
    }

    if (machines.isEmpty) {
      return const StateEmptyView(message: 'Belum ada unit mesin cuci yang terdaftar.');
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        itemCount: machines.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _MachineCard(
          machine: machines[index],
          onToggleStatus: onToggleStatus,
        ),
      ),
    );
  }
}

class _MachineCard extends StatelessWidget {
  const _MachineCard({required this.machine, required this.onToggleStatus});

  final MachineModel machine;
  final void Function(MachineModel) onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeFg, badgeText) = switch (machine.status) {
      'tersedia' => (const Color(0xFFDCFCE7), const Color(0xFF15803D), 'Tersedia'),
      'digunakan' => (const Color(0xFFE0F2FE), const Color(0xFF0369A1), 'Sedang Digunakan'),
      'maintenance' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C), 'Maintenance'),
      _ => (const Color(0xFFF1F5F9), AppTheme.textSecondary, machine.status),
    };

    return FrostedGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      blurSigma: 12,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.local_laundry_service_rounded, size: 26, color: badgeFg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      machine.machineCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        badgeText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Kapasitas: ${machine.capacityKg.toStringAsFixed(1)} kg'
                  '${machine.isDigunakan && machine.estimatedFinishAt != null ? ' • Selesai ~${Formatters.jam(machine.estimatedFinishAt!)}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (!machine.isDigunakan)
            OutlinedButton(
              onPressed: () => onToggleStatus(machine),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                machine.isMaintenance ? 'Aktifkan' : 'Perawatan',
                style: TextStyle(
                  fontSize: 11,
                  color: machine.isMaintenance ? AppTheme.success : AppTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
