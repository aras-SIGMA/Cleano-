/// Model data promo reward / penukaran poin member Cleano.
class RewardModel {
  const RewardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsRequired,
    required this.discountAmount,
    required this.isActive,
  });

  final int id;
  final String title;
  final String description;
  final int pointsRequired;
  final int discountAmount;
  final bool isActive;

  factory RewardModel.fromJson(Map<String, dynamic> json) {
    return RewardModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      pointsRequired: json['points_required'] is int
          ? json['points_required'] as int
          : int.tryParse(json['points_required']?.toString() ?? '0') ?? 0,
      discountAmount: json['discount_amount'] is int
          ? json['discount_amount'] as int
          : int.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'points_required': pointsRequired,
        'discount_amount': discountAmount,
        'is_active': isActive ? 1 : 0,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RewardModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
