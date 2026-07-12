import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goat_app/models/app_snapshot.dart';
import 'package:goat_app/models/parsed_diet_item.dart';
import 'package:goat_app/features/voice_entry/voice_entry_sheet.dart';
import 'package:goat_app/repositories/nutrition_repository.dart';
import 'package:goat_app/services/local_storage_service.dart';
import 'package:goat_app/services/nutrition_ai_service.dart';
import 'package:goat_app/services/speech_recognition_service.dart';
import 'package:goat_app/models/pending_cloud_deletes.dart';

class _FakeClient extends http.BaseClient {
  final String body;
  final Duration delay;

  _FakeClient(this.body, {this.delay = Duration.zero});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _FakeSpeechService implements SpeechRecognitionService {
  @override
  bool get isListening => false;

  @override
  Stream<SpeechState> get stateStream => const Stream<SpeechState>.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<SpeechInitResult> initialize() async =>
      const SpeechInitResult(available: true);

  @override
  Future<List<LocaleName>> locales() async => const [];

  @override
  Future<PermissionResult> requestPermission() async =>
      PermissionResult.granted;

  @override
  Future<SpeechResult> stopListening() async =>
      const SpeechResult(text: '', isFinal: true);

  @override
  Future<void> startListening({
    required void Function(String text) onPartial,
  }) async {}
}

class _FakeNutritionService implements NutritionAiService {
  @override
  Future<List<ParsedDietItem>> parseDietText(
    String text, {
    String defaultMealType = '加餐',
  }) async {
    return [
      ParsedDietItem(
        name: '鸡蛋',
        amount: 2,
        unit: '个',
        kcal: 140,
        protein: 12,
        carbs: 1,
        fat: 10,
        mealType: defaultMealType,
      ),
    ];
  }
}

class _FakeNutritionRepository implements NutritionRepository {
  List<ParsedDietItem> saved = [];

  @override
  Future<void> addRecords(List<ParsedDietItem> items) async {
    saved = [...items];
  }
}

void main() {
  test('parsed diet item accepts numeric strings and defaults', () {
    final item = ParsedDietItem.fromJson({
      'name': '牛奶',
      'amount': '250',
      'unit': 'ml',
      'kcal': '150',
      'p': '8',
      'c': '12',
      'f': '5',
    }, defaultMealType: '早餐');

    expect(item.amount, 250);
    expect(item.protein, 8);
    expect(item.mealType, '早餐');
  });

  test('snapshot merge de-duplicates records by stable id', () {
    final guest = AppSnapshot.fromJson({
      'foods': [
        {
          'id': 'food-1',
          'name': '旧名称',
          'protein': 1,
          'carbs': 2,
          'fat': 3,
          'calories': 4,
        },
      ],
    });
    final account = AppSnapshot.fromJson({
      'foods': [
        {
          'id': 'food-1',
          'name': '账号名称',
          'protein': 10,
          'carbs': 20,
          'fat': 30,
          'calories': 40,
        },
      ],
    });

    final merged = account.merge(guest);

    expect(merged.foods, hasLength(1));
    expect(merged.foods.single.name, '账号名称');
  });

  test('empty snapshot has no cloud deletion requests', () {
    final snapshot = AppSnapshot.empty();

    expect(snapshot.pendingCloudDeletes.isEmpty, isTrue);
    expect(snapshot.toJson()['pendingCloudDeletes'], isA<Map>());
  });

  test('only explicitly deleted remote ids enter the queue', () {
    const queue = PendingCloudDeletes(
      foodIds: {'food-1'},
      dietRecordIds: {'diet-1'},
    );

    expect(queue.foodIds, contains('food-1'));
    expect(queue.foodIds, isNot(contains('food-2')));
    expect(queue.dietRecordIds, contains('diet-1'));
  });

  test('failed cloud deletion keeps the pending queue', () {
    const queue = PendingCloudDeletes(foodIds: {'food-1'});
    const failedResult = PendingCloudDeletes.empty();

    expect(queue.without(failedResult).foodIds, contains('food-1'));
  });

  test('successful cloud deletion clears only processed ids', () {
    const queue = PendingCloudDeletes(foodIds: {'food-1', 'food-2'});
    const processed = PendingCloudDeletes(foodIds: {'food-1'});

    expect(queue.without(processed).foodIds, {'food-2'});
  });

  test('deletion queues are isolated when guest data is merged', () {
    final account = AppSnapshot.fromJson({
      'pendingCloudDeletes': {
        'foodIds': ['account-food'],
      },
    });
    final guest = AppSnapshot.fromJson({
      'pendingCloudDeletes': {
        'dietRecordIds': ['guest-diet'],
      },
    });

    final merged = account.merge(guest);

    expect(merged.pendingCloudDeletes.foodIds, {'account-food'});
    expect(merged.pendingCloudDeletes.dietRecordIds, {'guest-diet'});
  });

  test('old snapshots without a deletion queue remain readable', () {
    final snapshot = AppSnapshot.fromJson({'foods': []});

    expect(snapshot.pendingCloudDeletes.isEmpty, isTrue);
  });

  test(
    'nutrition service parses fenced JSON and skips invalid items',
    () async {
      final body = jsonEncode({
        'choices': [
          {
            'message': {
              'content': '''```json
[{"name":"鸡蛋","amount":"2","unit":"个","kcal":140,"protein":12,"carbs":1,"fat":10}, {"amount": 1}]
```''',
            },
          },
        ],
      });
      final service = DeepSeekNutritionAiService(
        apiKey: 'test-key',
        client: _FakeClient(body),
      );

      final items = await service.parseDietText('两个鸡蛋', defaultMealType: '早餐');

      expect(items, hasLength(1));
      expect(items.single.name, '鸡蛋');
      expect(items.single.amount, 2);
      expect(items.single.mealType, '早餐');
    },
  );

  test(
    'nutrition service rejects duplicate requests while a request is active',
    () async {
      final body = jsonEncode({
        'choices': [
          {
            'message': {
              'content':
                  '[{"name":"苹果","amount":1,"unit":"个","kcal":52,"protein":0,"carbs":14,"fat":0}]',
            },
          },
        ],
      });
      final service = DeepSeekNutritionAiService(
        apiKey: 'test-key',
        client: _FakeClient(body, delay: const Duration(milliseconds: 80)),
      );

      final first = service.parseDietText('苹果');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await expectLater(
        service.parseDietText('苹果'),
        throwsA(isA<NutritionAiException>()),
      );
      await first;
    },
  );

  test('legacy preferences migrate to the guest namespace', () async {
    SharedPreferences.setMockInitialValues({
      'user_gender': '女',
      'user_height': 168.0,
      'goat_database': jsonEncode([
        {
          'id': 'food-1',
          'name': '燕麦',
          'protein': 13,
          'carbs': 68,
          'fat': 7,
          'calories': 389,
        },
      ]),
    });
    final storage = await LocalStorageService.create();

    await storage.migrateLegacyGuestData();
    final snapshot = storage.load(storage.namespaceForUser(null));

    expect(snapshot?.gender, '女');
    expect(snapshot?.height, 168);
    expect(snapshot?.foods.single.name, '燕麦');
  });

  testWidgets('voice entry only saves after confirmation', (tester) async {
    final repository = _FakeNutritionRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceEntrySheet(
            initialMealType: '早餐',
            speechService: _FakeSpeechService(),
            nutritionService: _FakeNutritionService(),
            repository: repository,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '我吃了两个鸡蛋');
    await tester.tap(find.text('解析饮食'));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    expect(find.text('解析预览'), findsOneWidget);

    await tester.ensureVisible(find.text('确认记录'));
    await tester.tap(find.text('确认记录'));
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.mealType, '早餐');
  });
}
