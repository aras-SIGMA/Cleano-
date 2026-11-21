import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/order_model.dart';
import 'frosted_glass_card.dart';
import 'order_payment_badge.dart';

/// Kartu Pelacakan Pesanan Pelanggan dengan Visual Stepper 4 Tahap & Indikator Mesin.
class TrackingOrderCard extends StatelessWidget {
  const TrackingOrderCard({
    super.key,
    required this.order,
    required this.isHistory,
    required this.onTap,
  });

  final OrderModel order;
  final bool isHistory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrostedGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      blurSigma: 12,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: Kode Order, Tanggal, & Badge Bayar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.tanggal(order.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              OrderPaymentBadge(
                isLunas: order.isLunas,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Layanan & Berat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${order.serviceName} • ${Formatters.berat(order.weight)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Formatters.rupiah(order.totalPrice),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Visual Stepper 4 Tahap (khusus tab aktif)
          if (!isHistory) ...[
            _buildVisualStepper(order),
            const SizedBox(height: 14),
          ],

          // 4. Indikator Status Mesin / Antrean
          _buildMachineOrQueueBanner(order),

          // 5. Informasi Poin (untuk riwayat selesai)
          if (isHistory && order.pointsAwarded > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    'Mendapatkan +${order.pointsAwarded} Poin Loyalti',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMachineOrQueueBanner(OrderModel order) {
    if (order.isProsesCuci) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.rotate_right_rounded, color: Color(0xFF0284C7), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sedang Dicuci di Mesin ${order.machineCode ?? '-'}'
                '${order.machineFinishAt != null ? ' • Estimasi selesai ~${Formatters.jam(order.machineFinishAt!)}' : ''}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
              ),
            ),
          ],
        ),
      );
    }

    if (order.isAntre) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.queueWaitMinutes > 0
                    ? 'Menunggu Antrean — Estimasi ± ${order.queueWaitMinutes} Menit'
                    : 'Menunggu Alokasi Mesin Cuci',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
              ),
            ),
          ],
        ),
      );
    }

    if (order.isSiapDiambil) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cucian Siap Diambil di Outlet! 🎉',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
              ),
            ),
          ],
        ),
      );
    }

    if (order.isSedangDiproses) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.dry_cleaning_rounded, color: AppTheme.secondary, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pakaian sedang dalam proses pengerjaan.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVisualStepper(OrderModel order) {
    // Tahap: 0: Antre, 1: Proses Cuci / Diproses, 2: Siap Diambil, 3: Selesai
    final currentStep = switch (order.status) {
      'antre' => 0,
      'proses_cuci' || 'sedang_diproses' => 1,
      'siap_diambil' => 2,
      'selesai' => 3,
      _ => 0,
    };

    final steps = ['Antre', 'Cuci', 'Siap', 'Selesai'];

    return Row(
      children: List.generate(steps.length, (idx) {
        final isCompleted = idx < currentStep;
        final isCurrent = idx == currentStep;

        final color = (isCompleted || isCurrent) ? AppTheme.primary : const Color(0xFFCBD5E1);

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: idx == 0 ? Colors.transparent : (idx <= currentStep ? AppTheme.primary : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isCurrent ? AppTheme.primary : (isCompleted ? AppTheme.primary : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                          : (isCurrent
                              ? Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                              : const SizedBox.shrink()),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: idx == steps.length - 1 ? Colors.transparent : (idx < currentStep ? AppTheme.primary : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps[idx],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
