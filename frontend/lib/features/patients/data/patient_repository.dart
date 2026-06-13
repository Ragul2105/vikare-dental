import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_response.dart';
import '../../../core/api/base_repository.dart';
import '../../../core/models/pagination.dart';
import '../domain/patient_models.dart';

final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => PatientRepository(ref.read(apiClientProvider)),
);

class PatientRepository extends BaseRepository {
  PatientRepository(super.dio);

  Future<ApiResponse<PaginatedResponse<Patient>>> listPatients({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) => safeCall<PaginatedResponse<Patient>>(
    call: () => dio.get(
      ApiEndpoints.patients,
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page': page,
        'page_size': pageSize,
      },
    ),
    parser: (data) => PaginatedResponse<Patient>.fromJson(
      data as Map<String, dynamic>,
      Patient.fromJson,
    ),
  );

  Future<ApiResponse<Patient>> getPatient(String patientId) =>
      safeCall<Patient>(
        call: () => dio.get(ApiEndpoints.patient(patientId)),
        parser: (data) => Patient.fromJson(data as Map<String, dynamic>),
      );

  Future<ApiResponse<Patient>> createPatient(PatientPayload payload) =>
      safeCall<Patient>(
        call: () => dio.post(ApiEndpoints.patients, data: payload.toJson()),
        parser: (data) => Patient.fromJson(data as Map<String, dynamic>),
      );

  Future<ApiResponse<Patient>> updatePatient(
    String patientId,
    PatientPayload payload,
  ) => safeCall<Patient>(
    call: () =>
        dio.patch(ApiEndpoints.patient(patientId), data: payload.toJson()),
    parser: (data) => Patient.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<void>> deletePatient(String patientId, String reason) =>
      safeVoidCall(
        call: () => dio.delete(
          ApiEndpoints.patient(patientId),
          queryParameters: {'reason': reason},
        ),
      );

  Future<ApiResponse<List<PatientVisitSummary>>> listVisits(String patientId) =>
      safeCall<List<PatientVisitSummary>>(
        call: () => dio.get(ApiEndpoints.patientVisits(patientId)),
        parser: (data) {
          final items = (data as List<dynamic>? ?? const <dynamic>[]);
          return items
              .map(
                (item) =>
                    PatientVisitSummary.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false);
        },
      );
}
