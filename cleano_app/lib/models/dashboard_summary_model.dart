/// Model tren omzet per hari dalam 7 hari terakhir.
class DailyRevenueModel {
  const DailyRevenueModel({
    required this.orderDate,
    required this.dailyRevenue,
    required this.totalTransactions,
    required this.totalWeightKg,
  });

  final String orderDate;
  final int dailyRevenue;
  final int totalTransactions;
  final double totalWeightKg;

  factory DailyRevenueModel.fromJson(Map<String, dynamic> json) {
    return DailyRevenueModel(
      orderDate: json['order_date']?.toString() ?? '',
      dailyRevenue: json['daily_revenue'] is int
          ? json['daily_revenue'] as int
          : int.tryParse(json['daily_revenue']?.toString() ?? '0') ?? 0,
      totalTransactions: json['total_transactions'] is int
          ? json['total_transactions'] as int
          : int.tryParse(json['total_transactions']?.toString() ?? '0') ?? 0,
      totalWeightKg: json['total_weight_kg'] is num
          ? (json['total_weight_kg'] as num).toDouble()
          : double.tryParse(json['total_weight_kg']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'order_date': orderDate,
        'daily_revenue': dailyRevenue,
        'total_transactions': totalTransactions,
        'total_weight_kg': totalWeightKg,
      };
}

/// Model ringkasan dashboard operasional & kartu metrik kasir Cleano.
class DashboardSummaryModel {
  const DashboardSummaryModel({
    required this.todayRevenue,
    required this.activeOrders,
    required this.readyOrders,
    required this.availableMachines,
    required this.totalOperationalMachines,
    required this.revenue7Days,
  });

  final int todayRevenue;
  final int activeOrders;
  final int readyOrders;
  final int availableMachines;
  final int totalOperationalMachines;
  final List<DailyRevenueModel> revenue7Days;

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['revenue_7_days'];
    List<DailyRevenueModel> list = [];
    if (rawList is List) {
      list = rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => DailyRevenueModel.fromJson(m))
          .toList();
    }

    return DashboardSummaryModel(
      todayRevenue: json['today_revenue'] is int
          ? json['today_revenue'] as int
          : int.tryParse(json['today_revenue']?.toString() ?? '0') ?? 0,
      activeOrders: json['active_orders'] is int
          ? json['active_orders'] as int
          : int.tryParse(json['active_orders']?.toString() ?? '0') ?? 0,
      readyOrders: json['ready_orders'] is int
          ? json['ready_orders'] as int
          : int.tryParse(json['ready_orders']?.toString() ?? '0') ?? 0,
      availableMachines: json['available_machines'] is int
          ? json['available_machines'] as int
          : int.tryParse(json['available_machines']?.toString() ?? '0') ?? 0,
      totalOperationalMachines: json['total_operational_machines'] is int
          ? json['total_operational_machines'] as int
          : int.tryParse(json['total_operational_machines']?.toString() ?? '0') ?? 0,
      revenue7Days: list,
    );
  }

  Map<String, dynamic> toJson() => {
        'today_revenue': todayRevenue,
        'active_orders': activeOrders,
        'ready_orders': readyOrders,
        'available_machines': availableMachines,
        'total_operational_machines': totalOperationalMachines,
        'revenue_7_days': revenue7Days.map((d) => d.toJson()).toList(),
      };
}
