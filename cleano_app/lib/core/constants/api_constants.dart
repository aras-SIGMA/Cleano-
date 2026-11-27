import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konstanta akses API. Nilai berasal dari `.env`.
class ApiConstants {
  const ApiConstants._();

  /// Base URL backend tanpa trailing slash, otomatis menyesuaikan platform aktif.
  static String get baseUrl {
    var raw = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (raw.isEmpty) {
      raw = 'http://10.0.2.2:3000';
    }

    while (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }

    final useAdbReverse = dotenv.env['USE_ADB_REVERSE']?.trim().toLowerCase() == 'true';

    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      raw = raw.replaceFirst('10.0.2.2', 'localhost');
    } else if (defaultTargetPlatform == TargetPlatform.android && !useAdbReverse) {
      raw = raw
          .replaceFirst('localhost', '10.0.2.2')
          .replaceFirst('127.0.0.1', '10.0.2.2');
    }

    return raw;
  }

  // --- path endpoint auth & user ---
  static const health = '/api/health';
  static const register = '/api/auth/register';
  static const login = '/api/auth/login';
  static const changePassword = '/api/auth/change-password';
  static const userLookup = '/api/users/lookup';
  static const userMe = '/api/users/me';
  static const userAvatar = '/api/users/me/avatar';

  // --- master data ---
  static const services = '/api/services';
  static const machines = '/api/machines';
  static const rewards = '/api/rewards';
  static const rewardRedeem = '/api/rewards/redeem';
  static const rewardMyVouchers = '/api/rewards/my-vouchers';

  // --- orders & tracking ---
  static const orders = '/api/orders';

  // --- dashboard ---
  static const dashboardSummary = '/api/dashboard/summary';
}
