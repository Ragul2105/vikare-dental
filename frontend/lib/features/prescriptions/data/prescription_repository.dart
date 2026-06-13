import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_response.dart';
import '../../../core/api/base_repository.dart';
import '../../../core/config/app_config.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>(
  (ref) => PrescriptionRepository(ref.read(apiClientProvider)),
);

class PrescriptionDocument {
  const PrescriptionDocument({
    required this.id,
    required this.visitId,
    required this.pdfUrl,
    required this.createdAt,
  });

  final String id;
  final String visitId;
  final String pdfUrl;
  final DateTime createdAt;

  factory PrescriptionDocument.fromJson(Map<String, dynamic> json) =>
      PrescriptionDocument(
        id: json['id'] as String,
        visitId: json['visit_id'] as String,
        pdfUrl: AppConfig.resolveUrl(json['pdf_url'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class PrescriptionRepository extends BaseRepository {
  PrescriptionRepository(super.dio);

  Future<ApiResponse<PrescriptionDocument>> get(String visitId) =>
      safeCall<PrescriptionDocument>(
        call: () => dio.get(ApiEndpoints.prescription(visitId)),
        parser: (data) =>
            PrescriptionDocument.fromJson(data as Map<String, dynamic>),
      );

  Future<ApiResponse<PrescriptionDocument>> generate(String visitId) =>
      safeCall<PrescriptionDocument>(
        call: () => dio.post(ApiEndpoints.prescription(visitId)),
        parser: (data) =>
            PrescriptionDocument.fromJson(data as Map<String, dynamic>),
      );
}
