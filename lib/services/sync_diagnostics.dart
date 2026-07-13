import 'package:flutter/foundation.dart';

class SyncDiagnostics {
  const SyncDiagnostics._();

  static void queue({
    required String operationId,
    required String entityType,
    required int queueLength,
    required int retryCount,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'sync operation=$operationId entity=$entityType '
      'queue=$queueLength retries=$retryCount',
    );
  }
}
