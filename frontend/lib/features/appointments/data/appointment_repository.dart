import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_response.dart';
import '../../../core/api/base_repository.dart';
import '../../../core/utils/india_time.dart';
import '../domain/appointment_models.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(ref.read(apiClientProvider)),
);

class AppointmentRepository extends BaseRepository {
  AppointmentRepository(super.dio);

  Future<ApiResponse<AppointmentQueryResult>> listAppointments({
    required DateTime date,
    String range = 'day',
  }) => safeCall<AppointmentQueryResult>(
    call: () => dio.get(
      ApiEndpoints.appointments,
      queryParameters: {'date': IndiaTime.apiDate(date), 'range': range},
    ),
    parser: (data) =>
        AppointmentQueryResult.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<Appointment>> getAppointment(String appointmentId) =>
      safeCall<Appointment>(
        call: () => dio.get(ApiEndpoints.appointment(appointmentId)),
        parser: (data) => Appointment.fromJson(data as Map<String, dynamic>),
      );

  Future<ApiResponse<Appointment>> createAppointment(
    AppointmentCreatePayload payload,
  ) => safeCall<Appointment>(
    call: () => dio.post(ApiEndpoints.appointments, data: payload.toJson()),
    parser: (data) => Appointment.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<Appointment>> updateAppointment(
    String appointmentId,
    AppointmentUpdatePayload payload,
  ) => safeCall<Appointment>(
    call: () => dio.patch(
      ApiEndpoints.appointment(appointmentId),
      data: payload.toJson(),
    ),
    parser: (data) => Appointment.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<void>> cancelAppointment(
    String appointmentId, {
    String? reason,
  }) => safeVoidCall(
    call: () => dio.delete(
      ApiEndpoints.appointment(appointmentId),
      queryParameters: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    ),
  );
}
