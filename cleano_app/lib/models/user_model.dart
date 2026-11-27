/// Model data pengguna Cleano (kasir, pelanggan, atau owner).
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.memberCode,
    required this.points,
    required this.tier,
    this.avatarUrl,
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String memberCode;
  final int points;
  final String tier;
  final String? avatarUrl;

  bool get isKasir => role == 'kasir';
  bool get isPelanggan => role == 'pelanggan';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'pelanggan',
      memberCode: (json['member_code'] ?? json['memberCode'])?.toString() ?? '',
      points: json['points'] is int
          ? json['points'] as int
          : int.tryParse(json['points']?.toString() ?? '0') ?? 0,
      tier: json['tier']?.toString() ?? 'Silver',
      avatarUrl: _nonEmpty(json['avatar_url'] ?? json['avatarUrl']),
    );
  }

  static String? _nonEmpty(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'member_code': memberCode,
        'points': points,
        'tier': tier,
        'avatar_url': avatarUrl,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
