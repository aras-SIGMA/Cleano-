import 'next_queue_order_model.dart';

/// Model komprehensif data pesanan cucian (vw_order_details).
class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.customerName,
    required this.customerPhone,
    required this.memberCode,
    required this.customerTier,
    required this.customerCurrentTier,
    required this.serviceId,
    required this.serviceName,
    required this.pricePerKg,
    required this.requiresMachine,
    this.machineId,
    this.machineCode,
    this.machineFinishAt,
    required this.weight,
    required this.subtotalPrice,
    required this.discountAmount,
    required this.totalPrice,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paidAt,
    this.snapToken,
    this.snapRedirectUrl,
    required this.status,
    required this.queueWaitMinutes,
    required this.pointsAwarded,
    this.imageUrl,
    this.notes,
    this.voucherId,
    this.voucherCode,
    required this.createdAt,
    this.updatedAt,
    this.freedMachineId,
    this.nextQueueOrder,
  });

  final int id;
  final String orderCode;
  final int userId;
  final String customerName;
  final String customerPhone;
  final String memberCode;
  final String customerTier;
  final String customerCurrentTier;
  final int serviceId;
  final String serviceName;
  final int pricePerKg;
  final bool requiresMachine;
  final int? machineId;
  final String? machineCode;
  final DateTime? machineFinishAt;
  final double weight;
  final int subtotalPrice;
  final int discountAmount;
  final int totalPrice;
  final String paymentMethod; // 'tunai' | 'midtrans'
  final String paymentStatus; // 'belum_bayar' | 'lunas'
  final DateTime? paidAt;
  final String? snapToken;
  final String? snapRedirectUrl;
  final String status; // 'antre' | 'proses_cuci' | 'siap_diambil' | 'selesai' | 'batal'
  final int queueWaitMinutes;
  final int pointsAwarded;
  final String? imageUrl;
  final String? notes;
  final int? voucherId;
  final String? voucherCode;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? freedMachineId;
  final NextQueueOrderModel? nextQueueOrder;

  bool get isLunas => paymentStatus == 'lunas';
  bool get isBelumBayar => paymentStatus == 'belum_bayar';

  bool get isAntre => status == 'antre';
  bool get isProsesCuci => status == 'proses_cuci';
  bool get isSiapDiambil => status == 'siap_diambil';
  bool get isSelesai => status == 'selesai';
  bool get isBatal => status == 'batal';
  bool get isAktif => status == 'antre' || status == 'proses_cuci' || status == 'siap_diambil';

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null || v.toString().isEmpty) return null;
      return DateTime.tryParse(v.toString());
    }

    NextQueueOrderModel? nextQueue;
    if (json['next_queue_order'] is Map<String, dynamic>) {
      nextQueue = NextQueueOrderModel.fromJson(json['next_queue_order'] as Map<String, dynamic>);
    }

    return OrderModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderCode: (json['order_code'] ?? json['orderCode'])?.toString() ?? '',
      userId: json['user_id'] is int ? json['user_id'] as int : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      customerName: (json['customer_name'] ?? json['customerName'])?.toString() ?? '',
      customerPhone: (json['customer_phone'] ?? json['customerPhone'])?.toString() ?? '',
      memberCode: (json['member_code'] ?? json['memberCode'])?.toString() ?? '',
      customerTier: (json['customer_tier'] ?? json['customerTier'])?.toString() ?? 'Silver',
      customerCurrentTier: (json['customer_current_tier'] ?? json['customerCurrentTier'])?.toString() ?? 'Silver',
      serviceId: json['service_id'] is int ? json['service_id'] as int : int.tryParse(json['service_id']?.toString() ?? '0') ?? 0,
      serviceName: (json['service_name'] ?? json['serviceName'])?.toString() ?? '',
      pricePerKg: json['price_per_kg'] is int ? json['price_per_kg'] as int : int.tryParse(json['price_per_kg']?.toString() ?? '0') ?? 0,
      requiresMachine: json['requires_machine'] == 1 || json['requires_machine'] == true,
      machineId: json['machine_id'] != null ? int.tryParse(json['machine_id'].toString()) : null,
      machineCode: json['machine_code']?.toString(),
      machineFinishAt: parseDate(json['machine_finish_at']),
      weight: json['weight'] is num ? (json['weight'] as num).toDouble() : double.tryParse(json['weight']?.toString() ?? '0') ?? 0.0,
      subtotalPrice: json['subtotal_price'] is int ? json['subtotal_price'] as int : int.tryParse(json['subtotal_price']?.toString() ?? '0') ?? 0,
      discountAmount: json['discount_amount'] is int ? json['discount_amount'] as int : int.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,
      totalPrice: json['total_price'] is int ? json['total_price'] as int : int.tryParse(json['total_price']?.toString() ?? '0') ?? 0,
      paymentMethod: json['payment_method']?.toString() ?? 'tunai',
      paymentStatus: json['payment_status']?.toString() ?? 'belum_bayar',
      paidAt: parseDate(json['paid_at']),
      snapToken: json['snap_token']?.toString(),
      snapRedirectUrl: json['snap_redirect_url']?.toString(),
      status: json['status']?.toString() ?? 'antre',
      queueWaitMinutes: json['queue_wait_minutes'] is int ? json['queue_wait_minutes'] as int : int.tryParse(json['queue_wait_minutes']?.toString() ?? '0') ?? 0,
      pointsAwarded: json['points_awarded'] is int ? json['points_awarded'] as int : int.tryParse(json['points_awarded']?.toString() ?? '0') ?? 0,
      imageUrl: json['image_url']?.toString(),
      notes: json['notes']?.toString(),
      voucherId: json['voucher_id'] != null ? int.tryParse(json['voucher_id'].toString()) : null,
      voucherCode: json['voucher_code']?.toString(),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']),
      freedMachineId: json['freed_machine_id'] != null ? int.tryParse(json['freed_machine_id'].toString()) : null,
      nextQueueOrder: nextQueue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_code': orderCode,
        'user_id': userId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'member_code': memberCode,
        'customer_tier': customerTier,
        'customer_current_tier': customerCurrentTier,
        'service_id': serviceId,
        'service_name': serviceName,
        'price_per_kg': pricePerKg,
        'requires_machine': requiresMachine ? 1 : 0,
        if (machineId != null) 'machine_id': machineId,
        if (machineCode != null) 'machine_code': machineCode,
        if (machineFinishAt != null) 'machine_finish_at': machineFinishAt!.toIso8601String(),
        'weight': weight,
        'subtotal_price': subtotalPrice,
        'discount_amount': discountAmount,
        'total_price': totalPrice,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
        if (snapToken != null) 'snap_token': snapToken,
        if (snapRedirectUrl != null) 'snap_redirect_url': snapRedirectUrl,
        'status': status,
        'queue_wait_minutes': queueWaitMinutes,
        'points_awarded': pointsAwarded,
        if (imageUrl != null) 'image_url': imageUrl,
        if (notes != null) 'notes': notes,
        if (voucherId != null) 'voucher_id': voucherId,
        if (voucherCode != null) 'voucher_code': voucherCode,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (freedMachineId != null) 'freed_machine_id': freedMachineId,
        if (nextQueueOrder != null) 'next_queue_order': nextQueueOrder!.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
