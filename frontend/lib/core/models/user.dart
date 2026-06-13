class UserSummary {
  const UserSummary({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}

class UserProfile extends UserSummary {
  const UserProfile({
    required super.id,
    required super.name,
    required super.role,
    this.expiryEpochSeconds,
  });

  final int? expiryEpochSeconds;

  factory UserProfile.fromClaims(Map<String, dynamic> claims) => UserProfile(
    id: claims['sub']?.toString() ?? '',
    name: claims['name']?.toString() ?? '',
    role: claims['role']?.toString() ?? 'staff',
    expiryEpochSeconds: claims['exp'] is int ? claims['exp'] as int : null,
  );
}
