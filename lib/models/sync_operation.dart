import 'json_value.dart';

enum SyncAction { upsert, delete }

class SyncOperation {
  final String operationId;
  final String userId;
  final String entityType;
  final String entityId;
  final SyncAction action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? nextRetryAt;

  const SyncOperation({
    required this.operationId,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.nextRetryAt,
  });

  bool isReady([DateTime? now]) {
    final retryAt = nextRetryAt;
    return retryAt == null || !retryAt.isAfter(now ?? DateTime.now());
  }

  SyncOperation copyWith({
    Map<String, dynamic>? payload,
    int? retryCount,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
  }) {
    return SyncOperation(
      operationId: operationId,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload ?? this.payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'userId': userId,
    'entityType': entityType,
    'entityId': entityId,
    'action': action.name,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'nextRetryAt': nextRetryAt?.toIso8601String(),
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    final action = json['action'] == SyncAction.delete.name
        ? SyncAction.delete
        : SyncAction.upsert;
    return SyncOperation(
      operationId: stringValue(json['operationId']),
      userId: stringValue(json['userId'], 'guest'),
      entityType: stringValue(json['entityType'], 'snapshot'),
      entityId: stringValue(json['entityId'], 'snapshot'),
      action: action,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      createdAt:
          DateTime.tryParse(stringValue(json['createdAt'])) ?? DateTime.now(),
      retryCount: intValue(json['retryCount']),
      nextRetryAt: DateTime.tryParse(stringValue(json['nextRetryAt'])),
    );
  }
}
