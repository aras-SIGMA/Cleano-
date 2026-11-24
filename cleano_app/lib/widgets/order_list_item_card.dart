import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/order_model.dart';
import 'frosted_glass_card.dart';
import 'order_payment_badge.dart';

/// Kartu rincian pesanan kasir dengan informasi lengkap & tombol aksi cepat.
class OrderListItemCard extends StatelessWidget {
  const OrderListItemCard({
    super.key,
    required this.order,
    required this.isActionLoading,
    required this.onMarkReady,
    required this.onComplete,
    required this.onSyncPayment,
    required this.onCancel,
  });

  final OrderModel order;
  final bool isActionLoading;
  final VoidCallback onMarkReady;
  final VoidCallback onComplete;
  final VoidCallback onSyncPayment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return FrostedGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      blurSigma: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: Kode Order, Badge Status, Badge Bayar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderCode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildPaymentBadge(),
                  const SizedBox(width: 6),
                  _buildStatusBadge(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Baris Info Pelanggan & Layanan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.customerPhone} • ${order.serviceName}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.berat(order.weight),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  Text(
                    Formatters.rupiah(order.totalPrice),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 3. Status Alokasi Mesin / Antrean
          if (order.isProsesCuci && order.machineCode != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rotate_right_rounded, size: 14, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mesin: ${order.machineCode}'
                      '${order.machineFinishAt != null ? ' (Selesai ~${Formatters.jam(order.machineFinishAt!)})' : ''}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (order.isAntre) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.queueWaitMinutes > 0
                          ? 'Menunggu mesin kosong (estimasi ~${order.queueWaitMinutes} menit)'
                          : 'Menunggu alokasi mesin berikutnya',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 4. Tombol Aksi Operasional Berdasarkan Status
          if (_hasActionButton) ...[
            const SizedBox(height: 12),
            _buildActionButtons(),
          ],
        ],
      ),
    );
  }

  bool get _hasActionButton =>
      order.isProsesCuci ||
      order.isSedangDiproses ||
      order.isSiapDiambil ||
      (order.isBelumBayar && order.paymentMethod == 'midtrans') ||
      _canCancel;

  /// Pesanan yang belum dilunaskan boleh dibatalkan selama belum final.
  bool get _canCancel => order.isBelumBayar && !order.isSelesai && !order.isBatal;

  Widget _buildActionButtons() {
    if (isActionLoading) {
      return const Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (order.isBelumBayar && order.paymentMethod == 'midtrans') ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSyncPayment,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Cek Bayar', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Layanan tanpa mesin tidak punya drum untuk dilepas, tapi transisi
            // sedang_diproses -> siap_diambil tetap sah dan tetap butuh tombol.
            if (order.isProsesCuci || order.isSedangDiproses)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onMarkReady,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Tandai Siap Diambil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

            if (order.isSiapDiambil)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.task_alt_rounded, size: 16),
                  label: const Text('Selesaikan Pesanan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
        if (_canCancel) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Batalkan Pesanan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentBadge() => OrderPaymentBadge(isLunas: order.isLunas);

  Widget _buildStatusBadge() {
    final (bg, fg, text) = switch (order) {
      _ when order.isAntre => (const Color(0xFFFEF3C7), const Color(0xFFB45309), 'Antre'),
      _ when order.isProsesCuci => (const Color(0xFFE0F2FE), const Color(0xFF0369A1), 'Proses Cuci'),
      _ when order.isSedangDiproses => (const Color(0xFFEDE9FE), const Color(0xFF6D28D9), 'Sedang Diproses'),
      _ when order.isSiapDiambil => (const Color(0xFFDCFCE7), const Color(0xFF15803D), 'Siap Diambil'),
      _ when order.isSelesai => (const Color(0xFFF1F5F9), const Color(0xFF475569), 'Selesai'),
      _ when order.isBatal => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C), 'Batal'),
      _ => (const Color(0xFFF1F5F9), AppTheme.textSecondary, order.status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
