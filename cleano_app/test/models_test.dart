import 'package:flutter_test/flutter_test.dart';

import 'package:cleano_app/models/dashboard_summary_model.dart';
import 'package:cleano_app/models/machine_model.dart';
import 'package:cleano_app/models/next_queue_order_model.dart';
import 'package:cleano_app/models/order_model.dart';
import 'package:cleano_app/models/reward_model.dart';
import 'package:cleano_app/models/service_model.dart';
import 'package:cleano_app/models/voucher_model.dart';

void main() {
  group('ServiceModel', () {
    test('fromJson membaca format API dengan benar', () {
      final json = {
        'id': 1,
        'name': 'Cuci Komplit Reguler',
        'price_per_kg': 7000,
        'wash_duration_minutes': 45,
        'estimated_hours': 24,
        'requires_machine': 1,
        'description': 'Cuci, kering, dan setrika rapi.',
      };

      final service = ServiceModel.fromJson(json);

      expect(service.id, 1);
      expect(service.name, 'Cuci Komplit Reguler');
      expect(service.pricePerKg, 7000);
      expect(service.washDurationMinutes, 45);
      expect(service.estimatedHours, 24);
      expect(service.requiresMachine, isTrue);
      expect(service.description, 'Cuci, kering, dan setrika rapi.');
    });
  });

  group('MachineModel', () {
    test('fromJson membaca status dan estimasi waktu selesai', () {
      final json = {
        'id': 2,
        'machine_code': 'MC-02',
        'status': 'digunakan',
        'capacity_kg': '7.0',
        'estimated_finish_at': '2026-11-19T22:30:00.000Z',
      };

      final machine = MachineModel.fromJson(json);

      expect(machine.id, 2);
      expect(machine.machineCode, 'MC-02');
      expect(machine.status, 'digunakan');
      expect(machine.isDigunakan, isTrue);
      expect(machine.isTersedia, isFalse);
      expect(machine.capacityKg, 7.0);
      expect(machine.estimatedFinishAt, isNotNull);
    });
  });

  group('RewardModel', () {
    test('fromJson membaca properti reward dan is_active', () {
      final json = {
        'id': 1,
        'title': 'Diskon 5rb',
        'description': 'Potongan langsung Rp 5.000',
        'points_required': 50,
        'discount_amount': 5000,
        'is_active': 1,
      };

      final reward = RewardModel.fromJson(json);

      expect(reward.id, 1);
      expect(reward.pointsRequired, 50);
      expect(reward.discountAmount, 5000);
      expect(reward.isActive, isTrue);
    });
  });

  group('VoucherModel', () {
    test('fromJson membaca voucher aktif dan status terpakai', () {
      final json = {
        'id': 10,
        'voucher_code': 'CLN-VCR-8821',
        'reward_id': 1,
        'title': 'Potongan Hemat Rp 5.000',
        'discount_amount': 5000,
        'points_required': 50,
        'is_used': 0,
        'used_at': null,
      };

      final voucher = VoucherModel.fromJson(json);

      expect(voucher.voucherCode, 'CLN-VCR-8821');
      expect(voucher.discountAmount, 5000);
      expect(voucher.isUsed, isFalse);
      expect(voucher.usedAt, isNull);
    });
  });

  group('NextQueueOrderModel', () {
    test('fromJson membaca order antrean berikutnya', () {
      final json = {
        'id': 5,
        'order_code': 'CLN-20261119-0005',
        'weight': 3.5,
        'customer_name': 'Rina Marlina',
        'service_name': 'Cuci Kilat',
      };

      final next = NextQueueOrderModel.fromJson(json);

      expect(next.id, 5);
      expect(next.orderCode, 'CLN-20261119-0005');
      expect(next.weight, 3.5);
      expect(next.customerName, 'Rina Marlina');
      expect(next.serviceName, 'Cuci Kilat');
    });
  });

  group('OrderModel', () {
    test('fromJson membaca seluruh kolom vw_order_details', () {
      final json = {
        'id': 100,
        'order_code': 'CLN-20261119-0100',
        'user_id': 2,
        'customer_name': 'Rina Marlina',
        'customer_phone': '081234567890',
        'member_code': 'MBR-0001',
        'customer_tier': 'Gold',
        'customer_current_tier': 'Gold',
        'service_id': 1,
        'service_name': 'Cuci Komplit Reguler',
        'price_per_kg': 7000,
        'requires_machine': 1,
        'machine_id': 3,
        'machine_code': 'MC-03',
        'machine_finish_at': '2026-11-19T22:00:00.000Z',
        'weight': 4.5,
        'subtotal_price': 31500,
        'discount_amount': 5000,
        'total_price': 26500,
        'payment_method': 'tunai',
        'payment_status': 'lunas',
        'paid_at': '2026-11-19T21:00:00.000Z',
        'snap_token': null,
        'snap_redirect_url': null,
        'status': 'proses_cuci',
        'queue_wait_minutes': 0,
        'points_awarded': 2,
        'image_url': '/uploads/photo1.jpg',
        'notes': 'Pisahkan baju putih',
        'voucher_id': 10,
        'voucher_code': 'CLN-VCR-8821',
        'created_at': '2026-11-19T20:45:00.000Z',
        'updated_at': '2026-11-19T20:50:00.000Z',
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, 100);
      expect(order.orderCode, 'CLN-20261119-0100');
      expect(order.customerName, 'Rina Marlina');
      expect(order.weight, 4.5);
      expect(order.totalPrice, 26500);
      expect(order.isLunas, isTrue);
      expect(order.isBelumBayar, isFalse);
      expect(order.isProsesCuci, isTrue);
      expect(order.isAktif, isTrue);
      expect(order.machineCode, 'MC-03');
      expect(order.voucherCode, 'CLN-VCR-8821');
    });
  });

  group('DashboardSummaryModel', () {
    test('fromJson membaca metrik kartu dan deret 7 hari', () {
      final json = {
        'today_revenue': 120000,
        'active_orders': 5,
        'ready_orders': 2,
        'available_machines': 3,
        'total_operational_machines': 4,
        'revenue_7_days': [
          {
            'order_date': '2026-11-19',
            'daily_revenue': 120000,
            'total_transactions': 4,
            'total_weight_kg': 16.5,
          }
        ],
      };

      final summary = DashboardSummaryModel.fromJson(json);

      expect(summary.todayRevenue, 120000);
      expect(summary.activeOrders, 5);
      expect(summary.readyOrders, 2);
      expect(summary.availableMachines, 3);
      expect(summary.totalOperationalMachines, 4);
      expect(summary.revenue7Days.length, 1);
      expect(summary.revenue7Days.first.orderDate, '2026-11-19');
      expect(summary.revenue7Days.first.dailyRevenue, 120000);
    });
  });
}
