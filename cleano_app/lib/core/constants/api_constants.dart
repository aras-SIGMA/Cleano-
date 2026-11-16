import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konstanta akses API. Nilai berasal dari `.env` (lihat `.env.example`).
class ApiConstants {
  const ApiConstants._();

  /// Base URL backend, tanpa trailing slash.
  static String get baseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? '';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Client Key Midtrans Snap — aman di frontend, beda dari server key.
  static String get midtransClientKey => dotenv.env['MIDTRANS_CLIENT_KEY'] ?? '';

  // --- path endpoint (PRD-02 §4) ---
  static const health = '/api/health';

  static const register = '/api/auth/register';
  static const login = '/api/auth/login';

  static const userLookup = '/api/users/lookup';

  static const services = '/api/services';
  static const machines = '/api/machines';
  static const rewards = '/api/rewards';

  static const orders = '/api/orders';
  static const dashboardSummary = '/api/dashboard/summary';

  static const rewardsRedeem = '/api/rewards/redeem';
  static const myVouchers = '/api/rewards/my-vouchers';

  /// `PATCH /api/orders/:id/status`
  static String orderStatus(int id) => '/api/orders/$id/status';

  /// `PATCH /api/orders/:id/confirm-relay`
  static String orderConfirmRelay(int id) => '/api/orders/$id/confirm-relay';

  /// `POST /api/orders/:id/sync-payment`
  static String orderSyncPayment(int id) => '/api/orders/$id/sync-payment';
}