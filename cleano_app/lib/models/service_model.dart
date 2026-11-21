/// Model data katalog layanan laundry Cleano.
class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.pricePerKg,
    required this.washDurationMinutes,
    required this.estimatedHours,
    required this.requiresMachine,
    this.description,
  });

  final int id;
  final String name;
  final int pricePerKg;
  final int washDurationMinutes;
  final int estimatedHours;
  final bool requiresMachine;
  final String? description;

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      pricePerKg: json['price_per_kg'] is int
          ? json['price_per_kg'] as int
          : int.tryParse(json['price_per_kg']?.toString() ?? '0') ?? 0,
      washDurationMinutes: json['wash_duration_minutes'] is int
          ? json['wash_duration_minutes'] as int
          : int.tryParse(json['wash_duration_minutes']?.toString() ?? '0') ?? 0,
      estimatedHours: json['estimated_hours'] is int
          ? json['estimated_hours'] as int
          : int.tryParse(json['estimated_hours']?.toString() ?? '0') ?? 0,
      requiresMachine: json['requires_machine'] == 1 || json['requires_machine'] == true,
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price_per_kg': pricePerKg,
        'wash_duration_minutes': washDurationMinutes,
        'estimated_hours': estimatedHours,
        'requires_machine': requiresMachine ? 1 : 0,
        if (description != null) 'description': description,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
