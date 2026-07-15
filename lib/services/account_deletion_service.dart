import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_storage_service.dart';

class AccountDeletionService {
  static const confirmationPhrase = 'DELETE MY ACCOUNT';
  final SupabaseClient client;
  final LocalStorageService storage;
  AccountDeletionService({required this.client, required this.storage});

  Future<void> deleteCurrentAccount({required String confirmation}) async {
    if (confirmation != confirmationPhrase)
      throw ArgumentError.value(confirmation, 'confirmation');
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous)
      throw StateError('A signed-in account is required');
    await client.functions.invoke(
      'delete-account',
      body: {'confirmPhrase': confirmationPhrase},
    );
    await storage.clearNamespace(storage.namespaceForUser(user.id));
    await client.auth.signOut();
  }
}
