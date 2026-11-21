/// Model data mesin cuci Cleano (status: 'tersedia', 'digunakan', 'maintenance').
class MachineModel {
  const MachineModel({
    required this.id,
    required this.machineCode,
    required this.status,
    required this.capacityKg,
    this.estimatedFinishAt,
  });

  final int id;
  final String machineCode;
  final String status;
  final double capacityKg;
  final DateTime? estimatedFinishAt;

  bool get isTersedia => status == 'tersedia';
  bool get isDigunakan => status == 'digunakan';
  bool get isMaintenance => status == 'maintenance';

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    DateTime? finishAt;
    final rawFinish = json['estimated_finish_at'];
    if (rawFinish != null && rawFinish.toString().isNotEmpty) {
      finishAt = DateTime.tryParse(rawFinish.toString());
    }

    return MachineModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      machineCode: json['machine_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'tersedia',
      capacityKg: json['capacity_kg'] is num
          ? (json['capacity_kg'] as num).toDouble()
          : double.tryParse(json['capacity_kg']?.toString() ?? '0') ?? 0.0,
      estimatedFinishAt: finishAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'machine_code': machineCode,
        'status': status,
        'capacity_kg': capacityKg,
        if (estimatedFinishAt != null) 'estimated_finish_at': estimatedFinishAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
