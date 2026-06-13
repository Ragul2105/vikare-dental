class Patient {
  const Patient({
    required this.id,
    required this.patientUid,
    required this.name,
    required this.mobile,
    this.age,
    this.gender,
    this.address,
    this.medicalHistory,
    this.allergies,
    required this.whatsappEnabled,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String patientUid;
  final String name;
  final String mobile;
  final int? age;
  final String? gender;
  final String? address;
  final String? medicalHistory;
  final String? allergies;
  final bool whatsappEnabled;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'] as String,
    patientUid: json['patient_uid'] as String,
    name: json['name'] as String,
    mobile: json['mobile'] as String,
    age: json['age'] as int?,
    gender: json['gender'] as String?,
    address: json['address'] as String?,
    medicalHistory: json['medical_history'] as String?,
    allergies: json['allergies'] as String?,
    whatsappEnabled: json['whatsapp_enabled'] as bool? ?? true,
    isDeleted: json['is_deleted'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_uid': patientUid,
    'name': name,
    'mobile': mobile,
    'age': age,
    'gender': gender,
    'address': address,
    'medical_history': medicalHistory,
    'allergies': allergies,
    'whatsapp_enabled': whatsappEnabled,
    'is_deleted': isDeleted,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class PatientPayload {
  const PatientPayload({
    required this.name,
    required this.mobile,
    this.age,
    this.gender,
    this.address,
    this.medicalHistory,
    this.allergies,
    this.whatsappEnabled = true,
  });

  final String name;
  final String mobile;
  final int? age;
  final String? gender;
  final String? address;
  final String? medicalHistory;
  final String? allergies;
  final bool whatsappEnabled;

  Map<String, dynamic> toJson() => {
    'name': name,
    'mobile': mobile,
    'age': age,
    'gender': gender,
    'address': address,
    'medical_history': medicalHistory,
    'allergies': allergies,
    'whatsapp_enabled': whatsappEnabled,
  };
}

class PatientVisitSummary {
  const PatientVisitSummary({
    required this.id,
    required this.visitDate,
    this.diagnosis,
    this.notes,
    required this.photoCount,
    required this.treatmentCount,
    required this.medicationCount,
  });

  final String id;
  final DateTime visitDate;
  final String? diagnosis;
  final String? notes;
  final int photoCount;
  final int treatmentCount;
  final int medicationCount;

  factory PatientVisitSummary.fromJson(Map<String, dynamic> json) =>
      PatientVisitSummary(
        id: json['id'] as String,
        visitDate: DateTime.parse(json['visit_date'] as String),
        diagnosis: json['diagnosis'] as String?,
        notes: json['notes'] as String?,
        photoCount:
            (json['photos'] as List<dynamic>? ?? const <dynamic>[]).length,
        treatmentCount:
            (json['treatments'] as List<dynamic>? ?? const <dynamic>[]).length,
        medicationCount:
            (json['medications'] as List<dynamic>? ?? const <dynamic>[]).length,
      );
}
