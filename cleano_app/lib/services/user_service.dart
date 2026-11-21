import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import '../models/voucher_model.dart';
import 'api_service.dart';

/// Hasil pencarian data pelanggan (lookup POS via scan QR / nomor WhatsApp).
class CustomerLookupResult {
  const CustomerLookupResult({
    required this.user,
    required this.vouchers,
  });

  final UserModel user;
  final List<VoucherModel> vouchers;

  factory CustomerLookupResult.fromJson(Map<String, dynamic> json) {
    var rawVouchers = json['vouchers'];
    List<VoucherModel> voucherList = [];
    if (rawVouchers is List) {
      voucherList = rawVouchers
          .whereType<Map<String, dynamic>>()
          .map((v) => VoucherModel.fromJson(v))
          .toList();
    }

    return CustomerLookupResult(
      user: UserModel.fromJson(json),
      vouchers: voucherList,
    );
  }
}

/// Service untuk mencari data pelanggan di kasir POS.
class UserService {
  UserService({ApiService? apiService}) : _api = apiService ?? ApiService.instance;

  static final UserService instance = UserService();
  final ApiService _api;

  /// Mencari pelanggan berdasarkan kode member (MBR-XXXX) atau nomor HP.
  Future<CustomerLookupResult> lookup(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      throw const ApiException('Parameter pencarian wajib diisi.');
    }

    final res = await _api.get(
      ApiConstants.userLookup,
      query: {'query': cleanQuery},
    );

    final payload = res.data;
    if (payload is! Map<String, dynamic> || payload['data'] is! Map<String, dynamic>) {
      throw const ApiException('Data pelanggan tidak ditemukan.');
    }

    return CustomerLookupResult.fromJson(payload['data'] as Map<String, dynamic>);
  }
}
