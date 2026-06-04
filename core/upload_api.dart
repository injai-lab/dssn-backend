// lib/core/upload_api.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';

typedef ProgressCallback = void Function(int sent, int total);
typedef ItemProgressCallback = void Function(int index, int sent, int total);

class UploadApi {
  UploadApi._();
  static final UploadApi I = UploadApi._();

  final Dio _dio = ApiClient.I.dio;

  Future<String> uploadOne(
      File file, {
        ProgressCallback? onProgress,
      }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'upload.bin',
      ),
    });

    final res = await _dio.post(
      '/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onProgress,
    );

    final data = res.data;
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final url = (map['url'] as String?) ?? (map['abs_url'] as String?);
      if (url != null && url.isNotEmpty) return url;
    }
    if (data is String && data.isNotEmpty) {
      return data;
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      message: '업로드 응답을 이해할 수 없어요. (data=$data)',
      type: DioExceptionType.badResponse,
    );
  }

  Future<List<String>> uploadMany(
      List<File> files, {
        ItemProgressCallback? onItemProgress,
      }) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final url = await uploadOne(
        files[i],
        onProgress: (sent, total) => onItemProgress?.call(i, sent, total),
      );
      urls.add(url);
    }
    return urls;
  }
}
