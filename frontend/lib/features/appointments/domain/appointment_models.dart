import '../../../core/utils/india_time.dart';

class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    this.patientName,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    this.reason,
    this.notes,
    this.assignedPractitionerId,
    this.practitionerName,
  });

  final String id;
  final String patientId;
  final String? patientName;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String status;
  final String? reason;
  final String? notes;
  final String? assignedPractitionerId;
  final String? practitionerName;

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] as String,
    patientId: json['patient_id'] as String,
    patientName: json['patient_name'] as String?,
    scheduledAt: IndiaTime.fromApiDateTime(json['scheduled_at'] as String),
    durationMinutes: json['duration_minutes'] as int? ?? 30,
    status: json['status'] as String? ?? 'scheduled',
    reason: json['reason'] as String?,
    notes: json['notes'] as String?,
    assignedPractitionerId: json['assigned_practitioner_id'] as String?,
    practitionerName: json['practitioner_name'] as String?,
  );
}

class AppointmentQueryResult {
  const AppointmentQueryResult({
    required this.items,
    required this.range,
    required this.date,
  });

  final List<Appointment> items;
  final String range;
  final DateTime date;

  factory AppointmentQueryResult.fromJson(Map<String, dynamic> json) =>
      AppointmentQueryResult(
        items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        range: json['range'] as String? ?? 'day',
        date: DateTime.parse(json['date'] as String),
      );
}

class AppointmentCreatePayload {
  const AppointmentCreatePayload({
    required this.patientId,
    required this.scheduledAt,
    required this.durationMinutes,
    this.reason,
    this.notes,
    this.assignedPractitionerId,
  });

  final String patientId;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? reason;
  final String? notes;
  final String? assignedPractitionerId;

  Map<String, dynamic> toJson() => {
    'patient_id': patientId,
    'scheduled_at': IndiaTime.toApiDateTime(scheduledAt),
    'duration_minutes': durationMinutes,
    'reason': reason,
    'notes': notes,
    'assigned_practitioner_id': assignedPractitionerId,
  };
}

class AppointmentUpdatePayload {
  const AppointmentUpdatePayload({
    this.scheduledAt,
    this.durationMinutes,
    this.status,
    this.reason,
    this.notes,
    this.assignedPractitionerId,
  });

  final DateTime? scheduledAt;
  final int? durationMinutes;
  final String? status;
  final String? reason;
  final String? notes;
  final String? assignedPractitionerId;

  Map<String, dynamic> toJson() => {
    if (scheduledAt != null)
      'scheduled_at': IndiaTime.toApiDateTime(scheduledAt!),
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    if (status != null) 'status': status,
    if (reason != null) 'reason': reason,
    if (notes != null) 'notes': notes,
    if (assignedPractitionerId != null)
      'assigned_practitioner_id': assignedPractitionerId,
  };
}
