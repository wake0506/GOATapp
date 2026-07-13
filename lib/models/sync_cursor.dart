import 'json_value.dart';

class SyncCursor {
  final DateTime? lastSyncedAt;

  const SyncCursor({this.lastSyncedAt});

  const SyncCursor.empty() : this();

  bool get hasValue => lastSyncedAt != null;

  SyncCursor copyWith({DateTime? lastSyncedAt}) =>
      SyncCursor(lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt);

  Map<String, dynamic> toJson() => {
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  factory SyncCursor.fromJson(Object? value) {
    if (value is! Map) return const SyncCursor.empty();
    return SyncCursor(
      lastSyncedAt: DateTime.tryParse(stringValue(value['lastSyncedAt'])),
    );
  }
}
