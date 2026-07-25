class AccountDeletionService {
  const AccountDeletionService({
    required this.userId,
    required this.namespaceForUser,
    required this.invokeRemoteDelete,
    required this.clearLocalNamespace,
    required this.signOut,
  });

  static const confirmationPhrase = 'DELETE MY ACCOUNT';

  final String? userId;
  final String Function(String userId) namespaceForUser;
  final Future<void> Function(String confirmation) invokeRemoteDelete;
  final Future<void> Function(String namespace) clearLocalNamespace;
  final Future<void> Function() signOut;

  Future<String> deleteCurrentAccount({required String confirmation}) async {
    if (confirmation != confirmationPhrase) {
      throw ArgumentError.value(confirmation, 'confirmation', '确认短语不正确');
    }
    final id = userId;
    if (id == null || id.trim().isEmpty) {
      throw StateError('需要先登录账号');
    }
    final namespace = namespaceForUser(id);
    await invokeRemoteDelete(confirmation);
    Object? cleanupError;
    StackTrace? cleanupStack;
    try {
      await clearLocalNamespace(namespace);
    } catch (error, stack) {
      cleanupError = error;
      cleanupStack = stack;
    } finally {
      await signOut();
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStack!);
    }
    return namespace;
  }
}
