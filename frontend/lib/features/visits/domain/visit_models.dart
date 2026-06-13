import '../../../core/config/app_config.dart';

class VisitPhoto {
  const VisitPhoto({
    required this.id,
    required this.photoUrl,
    this.caption,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  final String id;
  final String photoUrl;
  final String? caption;
  final String uploadedBy;
  final DateTime uploadedAt;

  factory VisitPhoto.fromJson(Map<String, dynamic> json) => VisitPhoto(
    id: json['id'] as String,
    photoUrl: AppConfig.resolveUrl(json['photo_url'] as String),
    caption: json['caption'] as String?,
    uploadedBy: json['uploaded_by'] as String,
    uploadedAt: DateTime.parse(json['uploaded_at'] as String),
  );
}

class VisitTreatment {
  const VisitTreatment({
    required this.id,
    required this.treatmentId,
    required this.treatmentName,
    this.notes,
  });

  final String id;
  final String treatmentId;
  final String treatmentName;
  final String? notes;

  factory VisitTreatment.fromJson(Map<String, dynamic> json) => VisitTreatment(
    id: json['id'] as String,
    treatmentId: json['treatment_id'] as String,
    treatmentName: json['treatment_name'] as String? ?? '',
    notes: json['notes'] as String?,
  );
}

class VisitMedication {
  const VisitMedication({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.quantity,
  });

  final String id;
  final String medicationId;
  final String medicationName;
  final String dosage;
  final int quantity;

  factory VisitMedication.fromJson(Map<String, dynamic> json) =>
      VisitMedication(
        id: json['id'] as String,
        medicationId: json['medication_id'] as String,
        medicationName: json['medication_name'] as String? ?? '',
        dosage: json['dosage'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
      );
}

class Visit {
  const Visit({
    required this.id,
    required this.patientId,
    this.appointmentId,
    required this.visitDate,
    this.notes,
    this.diagnosis,
    required this.photos,
    required this.treatments,
    required this.medications,
  });

  final String id;
  final String patientId;
  final String? appointmentId;
  final DateTime visitDate;
  final String? notes;
  final String? diagnosis;
  final List<VisitPhoto> photos;
  final List<VisitTreatment> treatments;
  final List<VisitMedication> medications;

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
    id: json['id'] as String,
    patientId: json['patient_id'] as String,
    appointmentId: json['appointment_id'] as String?,
    visitDate: DateTime.parse(json['visit_date'] as String),
    notes: json['notes'] as String?,
    diagnosis: json['diagnosis'] as String?,
    photos: (json['photos'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => VisitPhoto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    treatments: (json['treatments'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => VisitTreatment.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    medications: (json['medications'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => VisitMedication.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );
}

class VisitMedicationItemPayload {
  const VisitMedicationItemPayload({
    required this.medicationId,
    required this.dosage,
    required this.quantity,
  });

  final String medicationId;
  final String dosage;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'medication_id': medicationId,
    'dosage': dosage,
    'quantity': quantity,
  };
}

class VisitCreatePayload {
  const VisitCreatePayload({
    required this.patientId,
    required this.visitDate,
    this.notes,
    this.diagnosis,
    this.appointmentId,
    this.treatmentIds = const <String>[],
    this.medicationItems = const <VisitMedicationItemPayload>[],
  });

  final String patientId;
  final DateTime visitDate;
  final String? notes;
  final String? diagnosis;
  final String? appointmentId;
  final List<String> treatmentIds;
  final List<VisitMedicationItemPayload> medicationItems;

  Map<String, dynamic> toJson() => {
    'patient_id': patientId,
    'appointment_id': appointmentId,
    'visit_date':
        '${visitDate.year.toString().padLeft(4, '0')}-${visitDate.month.toString().padLeft(2, '0')}-${visitDate.day.toString().padLeft(2, '0')}',
    'notes': notes,
    'diagnosis': diagnosis,
    'treatment_ids': treatmentIds,
    'medication_items': medicationItems.map((item) => item.toJson()).toList(),
  };
}

class VisitUpdatePayload {
  const VisitUpdatePayload({
    this.notes,
    this.diagnosis,
    this.treatmentIds,
    this.medicationItems,
  });

  final String? notes;
  final String? diagnosis;
  final List<String>? treatmentIds;
  final List<VisitMedicationItemPayload>? medicationItems;

  Map<String, dynamic> toJson() => {
    if (notes != null) 'notes': notes,
    if (diagnosis != null) 'diagnosis': diagnosis,
    if (treatmentIds != null) 'treatment_ids': treatmentIds,
    if (medicationItems != null)
      'medication_items': medicationItems!
          .map((item) => item.toJson())
          .toList(),
  };
}
