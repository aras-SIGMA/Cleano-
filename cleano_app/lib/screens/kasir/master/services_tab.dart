import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/service_model.dart';
import '../../../widgets/frosted_glass_card.dart';
import '../../../widgets/state_view.dart';

/// Tab 1 master data: daftar paket layanan beserta aksi edit dan hapus.
class ServicesTab extends StatelessWidget {
  const ServicesTab({
    super.key,
    required this.services,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ServiceModel> services;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(ServiceModel) onEdit;
  final void Function(ServiceModel) onDelete;

  @override
  Widget build(BuildContext context) {
    if (isLoading && services.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && services.isEmpty) {
      return StateErrorView(message: error!, onRetry: onRefresh);
    }

    if (services.isEmpty) {
      return const StateEmptyView(message: 'Belum ada paket layanan laundry yang terdaftar.');
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        itemCount: services.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ServiceCard(
          service: services[index],
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onEdit, required this.onDelete});

  final ServiceModel service;
  final void Function(ServiceModel) onEdit;
  final void Function(ServiceModel) onDelete;

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
                  service.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${Formatters.rupiah(service.pricePerKg)} / kg',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: service.requiresMachine ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  service.requiresMachine ? 'Pakai Mesin' : 'Tanpa Mesin',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: service.requiresMachine ? const Color(0xFF0369A1) : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estimasi: ${service.estimatedHours} jam • Cuci: ${service.washDurationMinutes} mnt',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (service.description != null && service.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              service.description!,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => onEdit(service),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => onDelete(service),
                icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.danger),
                label: const Text('Hapus', style: TextStyle(fontSize: 12, color: AppTheme.danger)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
