class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
  });

  final String id;
  final String name;
  final String role;
  final bool isActive;
  final DateTime? lastLoginAt;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    isActive: json['is_active'] as bool? ?? true,
    lastLoginAt: json['last_login_at'] == null
        ? null
        : DateTime.parse(json['last_login_at'] as String),
  );
}

class ActivityLogItem {
  const ActivityLogItem({
    required this.id,
    this.userId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.details,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  factory ActivityLogItem.fromJson(Map<String, dynamic> json) =>
      ActivityLogItem(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        action: json['action'] as String? ?? '',
        entityType: json['entity_type'] as String? ?? '',
        entityId: json['entity_id'] as String?,
        details: (json['details'] as Map?)?.cast<String, dynamic>(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
