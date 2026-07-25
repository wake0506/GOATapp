import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/profile/services/account_deletion_service.dart';
import 'package:goat_app/features/profile/services/user_data_export_service.dart';

void main() {
  group('cloud export', () {
    test('authenticated success delivers a real JSON artifact', () async {
      Uint8List? delivered;
      String? filename;
      final service = UserDataExportService(
        isAuthenticated: () => true,
        invokeExport: () async => {
          'schemaVersion': 1,
          'userProfile': {'height': 175},
        },
        deliver: (name, bytes) async {
          filename = name;
          delivered = bytes;
          return 'saved/$name';
        },
        clock: () => DateTime(2026, 7, 25),
      );

      final location = await service.exportCloudData();

      expect(location, 'saved/goat-cloud-data-2026-07-25.json');
      expect(filename, 'goat-cloud-data-2026-07-25.json');
      expect(jsonDecode(utf8.decode(delivered!)), isA<Map>());
    });

    test('unauthenticated export never invokes function or delivery', () async {
      var invoked = false;
      var delivered = false;
      final service = UserDataExportService(
        isAuthenticated: () => false,
        invokeExport: () async {
          invoked = true;
          return {};
        },
        deliver: (filename, bytes) async {
          delivered = true;
          return '';
        },
      );

      await expectLater(service.exportCloudData(), throwsStateError);
      expect(invoked, isFalse);
      expect(delivered, isFalse);
    });

    test('function failure is not converted to fake success', () async {
      final service = UserDataExportService(
        isAuthenticated: () => true,
        invokeExport: () => Future.error(StateError('network')),
        deliver: (filename, bytes) async => 'never',
      );

      await expectLater(service.exportCloudData(), throwsStateError);
    });

    test('malformed response is rejected before delivery', () async {
      var delivered = false;
      final service = UserDataExportService(
        isAuthenticated: () => true,
        invokeExport: () async => 'not json',
        deliver: (filename, bytes) async {
          delivered = true;
          return 'never';
        },
      );

      await expectLater(service.exportCloudData(), throwsFormatException);
      expect(delivered, isFalse);
    });

    test('download failure propagates and cannot report success', () async {
      final service = UserDataExportService(
        isAuthenticated: () => true,
        invokeExport: () async => {'ok': true},
        deliver: (filename, bytes) => Future.error(StateError('disk full')),
      );

      await expectLater(service.exportCloudData(), throwsStateError);
    });
  });

  test('local export contains explicit safe envelope', () async {
    Map<String, dynamic>? decoded;
    final service = LocalUserDataExportService(
      deliver: (_, bytes) async {
        decoded = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)) as Map,
        );
        return 'local.json';
      },
      clock: () => DateTime.utc(2026, 7, 25),
    );

    await service.export({
      'scope': 'current-account',
      'trainingTemplates': const [],
      'aiCoach': const {},
    });

    expect(decoded?['format'], 'goat-local-export-v1');
    expect(decoded?['scope'], 'current-account');
    expect(decoded, isNot(contains('apiKey')));
  });

  group('account deletion', () {
    test('wrong phrase stops before remote mutation', () async {
      var remote = false;
      final service = _deletionService(
        invokeRemote: (_) async => remote = true,
      );

      await expectLater(
        service.deleteCurrentAccount(confirmation: 'DELETE'),
        throwsArgumentError,
      );
      expect(remote, isFalse);
    });

    test('remote failure keeps local data and session intact', () async {
      var cleared = false;
      var signedOut = false;
      final service = _deletionService(
        invokeRemote: (_) => Future.error(StateError('function failed')),
        clear: (_) async => cleared = true,
        signOut: () async => signedOut = true,
      );

      await expectLater(
        service.deleteCurrentAccount(
          confirmation: AccountDeletionService.confirmationPhrase,
        ),
        throwsStateError,
      );
      expect(cleared, isFalse);
      expect(signedOut, isFalse);
    });

    test('success clears exact user namespace then signs out', () async {
      final events = <String>[];
      final service = _deletionService(
        invokeRemote: (phrase) async => events.add('remote:$phrase'),
        clear: (namespace) async => events.add('clear:$namespace'),
        signOut: () async => events.add('signout'),
      );

      final namespace = await service.deleteCurrentAccount(
        confirmation: AccountDeletionService.confirmationPhrase,
      );

      expect(namespace, 'ns-user-42');
      expect(events, [
        'remote:DELETE MY ACCOUNT',
        'clear:ns-user-42',
        'signout',
      ]);
    });

    test(
      'cleanup failure still signs out after remote account deletion',
      () async {
        var signedOut = false;
        final service = _deletionService(
          clear: (_) => Future.error(StateError('cleanup')),
          signOut: () async => signedOut = true,
        );

        await expectLater(
          service.deleteCurrentAccount(
            confirmation: AccountDeletionService.confirmationPhrase,
          ),
          throwsStateError,
        );
        expect(signedOut, isTrue);
      },
    );

    test('unauthenticated deletion is rejected', () async {
      final service = AccountDeletionService(
        userId: null,
        namespaceForUser: (id) => 'ns-$id',
        invokeRemoteDelete: (_) async {},
        clearLocalNamespace: (_) async {},
        signOut: () async {},
      );

      await expectLater(
        service.deleteCurrentAccount(
          confirmation: AccountDeletionService.confirmationPhrase,
        ),
        throwsStateError,
      );
    });
  });
}

AccountDeletionService _deletionService({
  Future<void> Function(String)? invokeRemote,
  Future<void> Function(String)? clear,
  Future<void> Function()? signOut,
}) => AccountDeletionService(
  userId: 'user-42',
  namespaceForUser: (id) => 'ns-$id',
  invokeRemoteDelete: invokeRemote ?? (_) async {},
  clearLocalNamespace: clear ?? (_) async {},
  signOut: signOut ?? () async {},
);
