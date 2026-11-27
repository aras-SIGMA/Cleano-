/// Model data ringkas pesanan antrean berikutnya untuk estafet mesin.
class NextQueueOrderModel {
  const NextQueueOrderModel({
    required this.id,
    required this.orderCode,
    required this.weight,
    required this.customerName,
    required this.serviceName,
  });

  final int id;
  final String orderCode;
  final double weight;
  final String customerName;
  final String serviceName;

  factory NextQueueOrderModel.fromJson(Map<String, dynamic> json) {
    return NextQueueOrderModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderCode: (json['order_code'] ?? json['orderCode'])?.toString() ?? '',
      weight: json['weight'] is num
          ? (json['weight'] as num).toDouble()
          : double.tryParse(json['weight']?.toString() ?? '0') ?? 0.0,
      customerName: (json['customer_name'] ?? json['customerName'])?.toString() ?? '',
      serviceName: (json['service_name'] ?? json['serviceName'])?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_code': orderCode,
        'weight': weight,
        'customer_name': customerName,
        'service_name': serviceName,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NextQueueOrderModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
