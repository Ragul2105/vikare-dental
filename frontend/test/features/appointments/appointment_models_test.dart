import 'package:flutter_test/flutter_test.dart';

import 'package:dental_clinic/features/appointments/domain/appointment_models.dart';

void main() {
  test('Appointment parses API timestamps as India wall clock time', () {
    final appointment = Appointment.fromJson({
      'id': 'apt-1',
      'patient_id': 'patient-1',
      'patient_name': 'Patient',
      'scheduled_at': '2026-05-11T10:45:00+00:00',
      'duration_minutes': 30,
      'status': 'scheduled',
    });

    expect(appointment.scheduledAt.year, 2026);
    expect(appointment.scheduledAt.month, 5);
    expect(appointment.scheduledAt.day, 11);
    expect(appointment.scheduledAt.hour, 16);
    expect(appointment.scheduledAt.minute, 15);
  });

  test(
    'Appointment payload serializes selected India wall clock time with IST offset',
    () {
      final payload = AppointmentCreatePayload(
        patientId: 'patient-1',
        scheduledAt: DateTime(2026, 5, 11, 16, 15),
        durationMinutes: 30,
        reason: 'Checkup',
      );

      expect(payload.toJson()['scheduled_at'], '2026-05-11T16:15:00+05:30');
    },
  );
}
