/// Model data voucher reward milik pelanggan (aktif atau sudah terpakai).
class VoucherModel {
  const VoucherModel({
    required this.id,
    required this.voucherCode,
    required this.rewardId,
    required this.title,
    required this.discountAmount,
    this.pointsRequired = 0,
    required this.isUsed,
    this.usedAt,
    this.createdAt,
  });

  final int id;
  final String voucherCode;
  final int rewardId;
  final String title;
  final int discountAmount;
  final int pointsRequired;
  final bool isUsed;
  final DateTime? usedAt;
  final DateTime? createdAt;

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    DateTime? used;
    if (json['used_at'] != null && json['used_at'].toString().isNotEmpty) {
      used = DateTime.tryParse(json['used_at'].toString());
    }

    DateTime? created;
    if (json['created_at'] != null && json['created_at'].toString().isNotEmpty) {
      created = DateTime.tryParse(json['created_at'].toString());
    }

    return VoucherModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      voucherCode: (json['voucher_code'] ?? json['voucherCode'])?.toString() ?? '',
      rewardId: json['reward_id'] is int
          ? json['reward_id'] as int
          : int.tryParse(json['reward_id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      discountAmount: json['discount_amount'] is int
          ? json['discount_amount'] as int
          : int.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,
      pointsRequired: json['points_required'] is int
          ? json['points_required'] as int
          : int.tryParse(json['points_required']?.toString() ?? '0') ?? 0,
      isUsed: json['is_used'] == 1 || json['is_used'] == true,
      usedAt: used,
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'voucher_code': voucherCode,
        'reward_id': rewardId,
        'title': title,
        'discount_amount': discountAmount,
        'points_required': pointsRequired,
        'is_used': isUsed ? 1 : 0,
        if (usedAt != null) 'used_at': usedAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoucherModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
