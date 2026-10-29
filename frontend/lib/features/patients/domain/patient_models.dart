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
    this.currentMedications,
    this.allergies,
    this.bloodType,
    this.clinicalFlags = const [],
    this.wasHospitalized = false,
    this.hospitalizationDate,
    this.hospitalizationReason,
    this.pastDentalHistory,
    required this.whatsappEnabled,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.lastVisitDate,
    this.doctorName,
  });

  final String id;
  final String patientUid;
  final String name;
  final String mobile;
  final int? age;
  final String? gender;
  final String? address;
  final String? medicalHistory;
  final String? currentMedications;
  final String? allergies;
  final String? bloodType;
  final List<String> clinicalFlags;
  final bool wasHospitalized;
  final DateTime? hospitalizationDate;
  final String? hospitalizationReason;
  final String? pastDentalHistory;
  final bool whatsappEnabled;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastVisitDate;
  final String? doctorName;

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'] as String,
    patientUid: json['patient_uid'] as String,
    name: json['name'] as String,
    mobile: json['mobile'] as String,
    age: json['age'] as int?,
    gender: json['gender'] as String?,
    address: json['address'] as String?,
    medicalHistory: json['medical_history'] as String?,
    currentMedications: json['current_medications'] as String?,
    allergies: json['allergies'] as String?,
    bloodType: json['blood_type'] as String?,
    clinicalFlags: (json['clinical_flags'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    wasHospitalized: json['was_hospitalized'] as bool? ?? false,
    hospitalizationDate: json['hospitalization_date'] == null
        ? null
        : DateTime.parse(json['hospitalization_date'] as String),
    hospitalizationReason: json['hospitalization_reason'] as String?,
    pastDentalHistory: json['past_dental_history'] as String?,
    whatsappEnabled: json['whatsapp_enabled'] as bool? ?? true,
    isDeleted: json['is_deleted'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    lastVisitDate: json['last_visit_date'] == null
        ? null
        : DateTime.parse(json['last_visit_date'] as String),
    doctorName: json['doctor_name'] as String?,
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
    'current_medications': currentMedications,
    'allergies': allergies,
    'blood_type': bloodType,
    'clinical_flags': clinicalFlags,
    'was_hospitalized': wasHospitalized,
    'hospitalization_date': hospitalizationDate
        ?.toIso8601String()
        .split('T')
        .first,
    'hospitalization_reason': hospitalizationReason,
    'past_dental_history': pastDentalHistory,
    'whatsapp_enabled': whatsappEnabled,
    'is_deleted': isDeleted,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'last_visit_date': lastVisitDate?.toIso8601String().split('T').first,
    'doctor_name': doctorName,
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
    this.currentMedications,
    this.allergies,
    this.bloodType,
    this.clinicalFlags = const [],
    this.wasHospitalized = false,
    this.hospitalizationDate,
    this.hospitalizationReason,
    this.pastDentalHistory,
    this.whatsappEnabled = true,
  });

  final String name;
  final String mobile;
  final int? age;
  final String? gender;
  final String? address;
  final String? medicalHistory;
  final String? currentMedications;
  final String? allergies;
  final String? bloodType;
  final List<String> clinicalFlags;
  final bool wasHospitalized;
  final DateTime? hospitalizationDate;
  final String? hospitalizationReason;
  final String? pastDentalHistory;
  final bool whatsappEnabled;

  Map<String, dynamic> toJson() => {
    'name': name,
    'mobile': mobile,
    'age': age,
    'gender': gender,
    'address': address,
    'medical_history': medicalHistory,
    'current_medications': currentMedications,
    'allergies': allergies,
    'blood_type': bloodType,
    'clinical_flags': clinicalFlags,
    'was_hospitalized': wasHospitalized,
    'hospitalization_date': hospitalizationDate
        ?.toIso8601String()
        .split('T')
        .first,
    'hospitalization_reason': hospitalizationReason,
    'past_dental_history': pastDentalHistory,
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
