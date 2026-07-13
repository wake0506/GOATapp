import '../models/app_snapshot.dart';
import '../models/pending_cloud_deletes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SyncRepository {
  Future<PendingCloudDeletes> syncSnapshot({
    required User user,
    required AppSnapshot snapshot,
  });

  Future<AppSnapshot?> fetchSnapshot(User user, {DateTime? lastSyncedAt});
}
