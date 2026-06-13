import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/master_data.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_response.dart';
import 'base_repository.dart';

final masterRepositoryProvider = Provider<MasterRepository>(
  (ref) => MasterRepository(ref.read(apiClientProvider)),
);

final treatmentsProvider = FutureProvider<List<TreatmentMaster>>((ref) async {
  final result = await ref.read(masterRepositoryProvider).listTreatments();
  return result.unwrap();
});

final medicationsProvider = FutureProvider<List<MedicationMaster>>((ref) async {
  final result = await ref.read(masterRepositoryProvider).listMedications();
  return result.unwrap();
});

class MasterRepository extends BaseRepository {
  MasterRepository(super.dio);

  Future<ApiResponse<List<TreatmentMaster>>> listTreatments() =>
      safeCall<List<TreatmentMaster>>(
        call: () => dio.get(ApiEndpoints.treatments),
        parser: (data) {
          final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
          return items
              .map(
                (item) =>
                    TreatmentMaster.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false);
        },
      );

  Future<ApiResponse<TreatmentMaster>> createTreatment({
    required String name,
    String? description,
    bool isActive = true,
  }) => safeCall<TreatmentMaster>(
    call: () => dio.post(
      ApiEndpoints.treatments,
      data: {'name': name, 'description': description, 'is_active': isActive},
    ),
    parser: (data) => TreatmentMaster.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<TreatmentMaster>> updateTreatment({
    required String id,
    required String name,
    String? description,
    required bool isActive,
  }) => safeCall<TreatmentMaster>(
    call: () => dio.patch(
      ApiEndpoints.treatment(id),
      data: {'name': name, 'description': description, 'is_active': isActive},
    ),
    parser: (data) => TreatmentMaster.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<List<MedicationMaster>>> listMedications() =>
      safeCall<List<MedicationMaster>>(
        call: () => dio.get(ApiEndpoints.medications),
        parser: (data) {
          final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
          return items
              .map(
                (item) =>
                    MedicationMaster.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false);
        },
      );

  Future<ApiResponse<MedicationMaster>> createMedication({
    required String name,
    String? description,
    String? defaultDosage,
    bool isActive = true,
  }) => safeCall<MedicationMaster>(
    call: () => dio.post(
      ApiEndpoints.medications,
      data: {
        'name': name,
        'description': description,
        'default_dosage': defaultDosage,
        'is_active': isActive,
      },
    ),
    parser: (data) => MedicationMaster.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<MedicationMaster>> updateMedication({
    required String id,
    required String name,
    String? description,
    String? defaultDosage,
    required bool isActive,
  }) => safeCall<MedicationMaster>(
    call: () => dio.patch(
      ApiEndpoints.medication(id),
      data: {
        'name': name,
        'description': description,
        'default_dosage': defaultDosage,
        'is_active': isActive,
      },
    ),
    parser: (data) => MedicationMaster.fromJson(data as Map<String, dynamic>),
  );
}
