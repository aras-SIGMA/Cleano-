import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/service_model.dart';
import 'language_picker_sheet.dart';

/// Dropdown pemilih layanan laundry Cleano di POS Kasir.
class ServiceDropdown extends StatelessWidget {
  const ServiceDropdown({
    super.key,
    required this.services,
    required this.selectedService,
    required this.onChanged,
    this.isLoading = false,
  });

  final List<ServiceModel> services;
  final ServiceModel? selectedService;
  final ValueChanged<ServiceModel?> onChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';

    if (isLoading) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(
              isEn ? 'Loading services...' : 'Memuat daftar layanan...',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ServiceModel>(
          isExpanded: true,
          value: selectedService,
          hint: Row(
            children: [
              const Icon(Icons.local_laundry_service_outlined, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 10),
              Text(l10n.selectLaundryService, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textPrimary),
          items: services.map((service) {
            return DropdownMenuItem<ServiceModel>(
              value: service,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${Formatters.rupiah(service.pricePerKg)}/kg • Est. ${service.estimatedHours} ${isEn ? 'hrs' : 'jam'}'
                          '${service.requiresMachine ? (isEn ? ' (Washing Machine)' : ' (Mesin Cuci)') : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      Formatters.rupiah(service.pricePerKg),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
