class TreatmentMaster {
  const TreatmentMaster({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;

  factory TreatmentMaster.fromJson(Map<String, dynamic> json) =>
      TreatmentMaster(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'is_active': isActive,
  };
}

class MedicationMaster {
  const MedicationMaster({
    required this.id,
    required this.name,
    this.description,
    this.defaultDosage,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? description;
  final String? defaultDosage;
  final bool isActive;

  factory MedicationMaster.fromJson(Map<String, dynamic> json) =>
      MedicationMaster(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        defaultDosage: json['default_dosage'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'default_dosage': defaultDosage,
    'is_active': isActive,
  };
}
