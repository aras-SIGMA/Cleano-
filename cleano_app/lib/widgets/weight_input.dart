import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

/// Komponen input berat cucian (kg) dengan dukungan desimal & tombol penyesuaian cepat.
class WeightInput extends StatelessWidget {
  const WeightInput({
    super.key,
    required this.controller,
    required this.weight,
    required this.onChanged,
    this.pricePerKg = 0,
  });

  final TextEditingController controller;
  final double weight;
  final ValueChanged<double> onChanged;
  final int pricePerKg;

  void _adjustWeight(double delta) {
    final current = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
    final next = (current + delta).clamp(0.0, 99.9);
    final rounded = (next * 10).round() / 10;
    controller.text = rounded.toStringAsFixed(1);
    onChanged(rounded);
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = (weight * pricePerKg).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Berat Cucian (kg)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (pricePerKg > 0)
                Text(
                  'Subtotal: ${Formatters.rupiah(subtotal)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
                  ],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.scale_rounded, color: AppTheme.primary),
                    suffixText: 'kg',
                    suffixStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                    hintText: '0.0',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                    onChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildStepButton(label: '-0.5', onTap: () => _adjustWeight(-0.5)),
              const SizedBox(width: 6),
              _buildStepButton(label: '+0.5', onTap: () => _adjustWeight(0.5)),
              const SizedBox(width: 6),
              _buildStepButton(label: '+1.0', onTap: () => _adjustWeight(1.0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}
