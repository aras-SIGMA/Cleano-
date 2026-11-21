import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../models/order_model.dart';
import 'api_service.dart';

/// Hasil daftar pesanan dengan metadata pagination.
class OrderListResult {
  const OrderListResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<OrderModel> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
}

/// Service manajemen transaksi pesanan laundry.
class OrderService {
  OrderService({ApiService? apiService}) : _api = apiService ?? ApiService.instance;

  static final OrderService instance = OrderService();
  final ApiService _api;

  /// Membuat pesanan baru (mendukung upload foto bukti drop-off).
  Future<OrderModel> createOrder({
    required int userId,
    required int serviceId,
    required double weight,
    required String paymentMethod, // 'tunai' | 'midtrans'
    String? notes,
    String? voucherCode,
    String? photoPath,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    MultipartFile? file;
    if (photoBytes != null) {
      file = MultipartFile.fromBytes(photoBytes, filename: photoFileName ?? 'bukti_cuci.jpg');
    } else if (photoPath != null && photoPath.isNotEmpty) {
      file = await MultipartFile.fromFile(photoPath);
    }

    final formData = FormData.fromMap({
      'user_id': userId,
      'service_id': serviceId,
      'weight': weight,
      'payment_method': paymentMethod,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (voucherCode != null && voucherCode.trim().isNotEmpty) 'voucher_code': voucherCode.trim(),
      'image': ?file,
    });

    final res = await _api.postMultipart(ApiConstants.orders, formData);
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return OrderModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal memproses transaksi pesanan.');
  }

  /// Mengambil daftar pesanan dengan filter status dan pagination.
  Future<OrderListResult> getOrders({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (status != null && status.isNotEmpty && status != 'semua') 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final res = await _api.get(ApiConstants.orders, query: queryParams);
    final payload = res.data;

    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      final data = payload['data'] as Map<String, dynamic>;
      final rawItems = data['items'];
      List<OrderModel> items = [];
      if (rawItems is List) {
        items = rawItems
            .whereType<Map<String, dynamic>>()
            .map((o) => OrderModel.fromJson(o))
            .toList();
      }

      return OrderListResult(
        items: items,
        page: data['page'] is int ? data['page'] as int : page,
        pageSize: data['pageSize'] is int ? data['pageSize'] as int : pageSize,
        total: data['total'] is int ? data['total'] as int : items.length,
        totalPages: data['totalPages'] is int ? data['totalPages'] as int : 1,
      );
    }

    return OrderListResult(items: [], page: page, pageSize: pageSize, total: 0, totalPages: 1);
  }

  /// Membaca detail lengkap satu pesanan.
  Future<OrderModel> getOrderDetail(int id) async {
    final res = await _api.get('${ApiConstants.orders}/$id');
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return OrderModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Detail pesanan tidak ditemukan.');
  }

  /// Memperbarui status pesanan ('antre' -> 'proses_cuci' -> 'siap_diambil' -> 'selesai' / 'batal').
  Future<OrderModel> updateStatus(int id, String status) async {
    final res = await _api.patch(
      '${ApiConstants.orders}/$id/status',
      data: {'status': status},
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return OrderModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal memperbarui status pesanan.');
  }

  /// Mengonfirmasi estafet cucian antrean berikutnya ke mesin yang baru saja kosong.
  Future<OrderModel> confirmRelay(int id, int machineId) async {
    final res = await _api.patch(
      '${ApiConstants.orders}/$id/confirm-relay',
      data: {'machine_id': machineId},
    );

    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return OrderModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal mengonfirmasi mesin untuk antrean pesanan.');
  }

  /// Menyinkronkan status pembayaran Midtrans Snap dengan gateway.
  Future<OrderModel> syncPayment(int id) async {
    final res = await _api.post('${ApiConstants.orders}/$id/sync-payment');
    final payload = res.data;
    if (payload is Map<String, dynamic> && payload['data'] is Map<String, dynamic>) {
      return OrderModel.fromJson(payload['data'] as Map<String, dynamic>);
    }
    throw const ApiException('Gagal menyinkronkan status pembayaran.');
  }
}
