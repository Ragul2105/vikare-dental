import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_response.dart';
import '../../../core/api/base_repository.dart';
import '../../../core/config/app_config.dart';
import '../domain/visit_models.dart';

final visitRepositoryProvider = Provider<VisitRepository>(
  (ref) => VisitRepository(ref.read(apiClientProvider)),
);

class VisitRepository extends BaseRepository {
  VisitRepository(super.dio);

  Future<ApiResponse<Visit>> createVisit(VisitCreatePayload payload) =>
      safeCall<Visit>(
        call: () => dio.post(ApiEndpoints.visits, data: payload.toJson()),
        parser: (data) => Visit.fromJson(data as Map<String, dynamic>),
      );

  Future<ApiResponse<Visit>> getVisit(String visitId) => safeCall<Visit>(
    call: () => dio.get(ApiEndpoints.visit(visitId)),
    parser: (data) => Visit.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<Visit>> updateVisit(
    String visitId,
    VisitUpdatePayload payload,
  ) => safeCall<Visit>(
    call: () => dio.patch(ApiEndpoints.visit(visitId), data: payload.toJson()),
    parser: (data) => Visit.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<List<VisitPhoto>>> uploadPhotos({
    required String visitId,
    required List<XFile> files,
    List<String?> captions = const <String?>[],
  }) async {
    try {
      final formData = FormData();

      for (var index = 0; index < files.length; index++) {
        final compressed = await _compress(files[index]);
        formData.files.add(
          MapEntry(
            'files',
            MultipartFile.fromBytes(
              compressed,
              filename: 'visit_${visitId}_$index.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          ),
        );
        final caption = index < captions.length ? captions[index] : null;
        if (caption != null && caption.trim().isNotEmpty) {
          formData.fields.add(MapEntry('captions', caption.trim()));
        }
      }

      final response = await dio.post<dynamic>(
        ApiEndpoints.visitPhotos(visitId),
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          sendTimeout: AppConfig.uploadTimeout,
        ),
      );

      final items = (response.data as List<dynamic>? ?? const <dynamic>[])
          .map((item) => VisitPhoto.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      return ApiSuccess<List<VisitPhoto>>(items);
    } on DioException catch (exception) {
      final error = exception.error;
      if (error is AppError) {
        return ApiFailure<List<VisitPhoto>>(error);
      }
      return ApiFailure<List<VisitPhoto>>(
        AppError(
          errorCode: 'UPLOAD_FAILED',
          message: exception.message ?? 'Photo upload failed.',
          statusCode: exception.response?.statusCode,
        ),
      );
    }
  }

  Future<ApiResponse<void>> deletePhoto(String visitId, String photoId) =>
      safeVoidCall(
        call: () => dio.delete(ApiEndpoints.visitPhoto(visitId, photoId)),
      );

  Future<List<int>> _compress(XFile file) async {
    final bytes = await file.readAsBytes();
    return FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 85,
      format: CompressFormat.jpeg,
    );
  }
}
