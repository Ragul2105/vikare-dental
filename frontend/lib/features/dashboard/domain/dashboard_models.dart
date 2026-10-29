import '../../../core/utils/india_time.dart';

class DashboardAppointment {
  const DashboardAppointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    this.reason,
  });

  final String id;
  final String patientId;
  final String patientName;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String status;
  final String? reason;

  factory DashboardAppointment.fromJson(Map<String, dynamic> json) =>
      DashboardAppointment(
        id: json['id'] as String,
        patientId: json['patient_id'] as String,
        patientName: json['patient_name'] as String? ?? 'Unknown patient',
        scheduledAt: IndiaTime.fromApiDateTime(json['scheduled_at'] as String),
        durationMinutes: json['duration_minutes'] as int? ?? 0,
        status: json['status'] as String? ?? 'scheduled',
        reason: json['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_id': patientId,
    'patient_name': patientName,
    'scheduled_at': IndiaTime.toApiDateTime(scheduledAt),
    'duration_minutes': durationMinutes,
    'status': status,
    'reason': reason,
  };
}

class DashboardSummary {
  const DashboardSummary({
    required this.today,
    required this.appointmentsToday,
    required this.appointments,
    required this.totalPatients,
    required this.totalStaff,
    required this.completedToday,
    required this.newPatientsThisMonth,
    required this.topTreatments,
    required this.appointmentTrend,
  });

  final DateTime today;
  final int appointmentsToday;
  final List<DashboardAppointment> appointments;
  final int totalPatients;
  final int totalStaff;
  final int completedToday;
  final int newPatientsThisMonth;
  final List<DashboardTreatment> topTreatments;
  final List<DashboardTrendPoint> appointmentTrend;

  factory DashboardSummary.fromJson(
    Map<String, dynamic> json,
  ) => DashboardSummary(
    today: DateTime.parse(json['today'] as String),
    appointmentsToday: json['appointments_today'] as int? ?? 0,
    appointments: (json['appointments'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => DashboardAppointment.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
    totalPatients: json['total_patients'] as int? ?? 0,
    totalStaff: json['total_staff'] as int? ?? 0,
    completedToday: json['completed_today'] as int? ?? 0,
    newPatientsThisMonth: json['new_patients_this_month'] as int? ?? 0,
    topTreatments: (json['top_treatments'] as List<dynamic>? ?? const [])
        .map(
          (item) => DashboardTreatment.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
    appointmentTrend: (json['appointment_trend'] as List<dynamic>? ?? const [])
        .map(
          (item) => DashboardTrendPoint.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'today': today.toIso8601String(),
    'appointments_today': appointmentsToday,
    'appointments': appointments.map((item) => item.toJson()).toList(),
    'total_patients': totalPatients,
    'total_staff': totalStaff,
    'completed_today': completedToday,
    'new_patients_this_month': newPatientsThisMonth,
    'top_treatments': topTreatments.map((item) => item.toJson()).toList(),
    'appointment_trend': appointmentTrend.map((item) => item.toJson()).toList(),
  };
}

class DashboardTreatment {
  const DashboardTreatment({required this.name, required this.count});
  final String name;
  final int count;

  factory DashboardTreatment.fromJson(Map<String, dynamic> json) =>
      DashboardTreatment(
        name: json['name'] as String,
        count: json['count'] as int? ?? 0,
      );
  Map<String, dynamic> toJson() => {'name': name, 'count': count};
}

class DashboardTrendPoint {
  const DashboardTrendPoint({required this.month, required this.count});
  final String month;
  final int count;

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) =>
      DashboardTrendPoint(
        month: json['month'] as String,
        count: json['count'] as int? ?? 0,
      );
  Map<String, dynamic> toJson() => {'month': month, 'count': count};
}
