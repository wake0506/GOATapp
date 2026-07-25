import 'dart:convert';
import 'dart:typed_data';

typedef JsonFileDeliverer =
    Future<String> Function(String filename, Uint8List bytes);

class UserDataExportService {
  const UserDataExportService({
    required this.isAuthenticated,
    required this.invokeExport,
    required this.deliver,
    this.clock = DateTime.now,
  });

  final bool Function() isAuthenticated;
  final Future<Object?> Function() invokeExport;
  final JsonFileDeliverer deliver;
  final DateTime Function() clock;

  Future<String> exportCloudData() async {
    if (!isAuthenticated()) {
      throw StateError('请先登录后再导出云端数据');
    }
    final response = await invokeExport();
    final normalized = _normalizeResponse(response);
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(normalized)));
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError('导出文件超过 5 MB，暂时无法在 App 内保存');
    }
    return deliver(_filename('goat-cloud-data'), bytes);
  }

  Object _normalizeResponse(Object? response) {
    if (response is Map || response is List) return response!;
    if (response is String && response.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response);
        if (decoded is Map || decoded is List) return decoded;
      } on FormatException {
        // Converted into a stable product-facing error below.
      }
    }
    throw const FormatException('云端返回的数据格式不完整，请稍后重试');
  }

  String _filename(String prefix) {
    final date = clock().toIso8601String().substring(0, 10);
    return '$prefix-$date.json';
  }
}

class LocalUserDataExportService {
  const LocalUserDataExportService({
    required this.deliver,
    this.clock = DateTime.now,
  });

  final JsonFileDeliverer deliver;
  final DateTime Function() clock;

  Future<String> export(Map<String, Object?> data) async {
    final payload = <String, Object?>{
      'format': 'goat-local-export-v1',
      'exportedAt': clock().toUtc().toIso8601String(),
      ...data,
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final date = clock().toIso8601String().substring(0, 10);
    return deliver('goat-local-data-$date.json', bytes);
  }
}
