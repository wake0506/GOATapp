import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:goat_app/models/app_snapshot.dart';
import 'package:goat_app/models/consumed_record.dart';
import 'package:goat_app/models/parsed_diet_item.dart';
import 'package:goat_app/features/voice_entry/voice_entry_sheet.dart';
import 'package:goat_app/repositories/nutrition_repository.dart';
import 'package:goat_app/services/local_storage_service.dart';
import 'package:goat_app/services/nutrition_ai_service.dart';
import 'package:goat_app/services/nutrition_quick_access_service.dart';
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
  List<ConsumedRecord> recordsForDate(String date) => const [];

  @override
  Future<void> addRecords(List<ParsedDietItem> items) async {
    saved = [...items];
  }

  @override
  Future<void> addConsumedRecords(List<ConsumedRecord> records) async {}

  @override
  Future<void> updateRecord(ConsumedRecord record) async {}

  @override
  Future<void> deleteRecord(String recordId) async {}

  @override
  Future<void> restoreRecord(ConsumedRecord record) async {}

  @override
  Future<void> replaceRecordsForOperation(List<ConsumedRecord> records) async {}
}

class _FakeSpeechToText extends stt.SpeechToText {
  _FakeSpeechToText() : super.withMethodChannel();

  bool emitListening = true;
  bool emitPrematureTerminal = false;
  bool emitDoneAfterStart = false;
  String? partialOnStart;
  String? resultOnStop;
  int listenCalls = 0;
  bool _listening = false;
  stt.SpeechStatusListener? _onStatus;
  stt.SpeechResultListener? _onResult;
  stt.SpeechSoundLevelChange? _onSoundLevel;
  stt.SpeechListenOptions? lastOptions;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = stt.SpeechToText.defaultFinalTimeout,
    List<stt.SpeechConfigOption>? options,
  }) async {
    _onStatus = onStatus;
    return true;
  }

  @override
  Future<List<stt.LocaleName>> locales() async => [
    stt.LocaleName('zh_CN', 'Chinese'),
  ];

  @override
  Future<stt.LocaleName?> systemLocale() async =>
      stt.LocaleName('zh_CN', 'Chinese');

  @override
  Future<void> listen({
    stt.SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
    sampleRate = 0,
    stt.SpeechListenOptions? listenOptions,
  }) async {
    listenCalls++;
    _onResult = onResult;
    _onSoundLevel = onSoundLevelChange;
    lastOptions = listenOptions;
    if (emitPrematureTerminal) {
      _onStatus?.call('notListening');
      return;
    }
    if (emitListening) {
      _listening = true;
      _onStatus?.call('listening');
    }
    if (partialOnStart != null) emitPartial(partialOnStart!);
    if (emitDoneAfterStart) {
      Future<void>.microtask(() => _onStatus?.call('done'));
    }
  }

  void emitSoundLevel(double level) => _onSoundLevel?.call(level);

  void emitPartial(String text) {
    _onResult?.call(
      SpeechRecognitionResult([
        SpeechRecognitionWords(text, null, -1),
      ], ResultType.partial.value),
    );
  }

  @override
  Future<void> stop() async {
    _listening = false;
    final text = resultOnStop;
    if (text != null) {
      _onResult?.call(
        SpeechRecognitionResult([
          SpeechRecognitionWords(text, null, -1),
        ], ResultType.finalResult.value),
      );
    }
    _onStatus?.call('done');
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    _onStatus?.call('notListening');
  }
}

void main() {
  test('speech startup terminal status is not recognized success', () async {
    final engine = _FakeSpeechToText()..emitPrematureTerminal = true;
    final service = DeviceSpeechRecognitionService(
      speech: engine,
      startupTimeout: const Duration(milliseconds: 40),
    );
    final states = <SpeechState>[];
    final subscription = service.stateStream.listen(states.add);

    await service.initialize();
    await service.startListening(onPartial: (_) {});

    expect(states, contains(SpeechState.error));
    expect(states, isNot(contains(SpeechState.recognized)));
    await subscription.cancel();
    await service.dispose();
  });

  test('listening state only follows platform listening callback', () async {
    final engine = _FakeSpeechToText();
    final service = DeviceSpeechRecognitionService(speech: engine);
    final states = <SpeechState>[];
    final subscription = service.stateStream.listen(states.add);

    await service.initialize();
    await service.startListening(onPartial: (_) {});

    expect(states, contains(SpeechState.listening));
    expect(engine.lastOptions?.listenMode, stt.ListenMode.dictation);
    expect(engine.lastOptions?.pauseFor, const Duration(seconds: 5));
    await subscription.cancel();
    await service.dispose();
  });

  test('platform done preserves partial text without empty success', () async {
    final engine = _FakeSpeechToText()
      ..emitDoneAfterStart = true
      ..partialOnStart = '早餐两个鸡蛋';
    final service = DeviceSpeechRecognitionService(speech: engine);
    final states = <SpeechState>[];
    final partials = <String>[];
    final subscription = service.stateStream.listen(states.add);

    await service.initialize();
    final start = service.startListening(onPartial: partials.add);
    await Future<void>.delayed(Duration.zero);
    engine.emitPartial('早餐两个鸡蛋');
    await start;
    await Future<void>.delayed(Duration.zero);

    expect(partials, contains('早餐两个鸡蛋'));
    expect(states, contains(SpeechState.recognized));
    await subscription.cancel();
    await service.dispose();
  });

  test('manual stop returns final text after finalizing', () async {
    final engine = _FakeSpeechToText()..resultOnStop = '早餐两个鸡蛋';
    final service = DeviceSpeechRecognitionService(speech: engine);
    final states = <SpeechState>[];
    final subscription = service.stateStream.listen(states.add);

    await service.initialize();
    await service.startListening(onPartial: (_) {});
    final result = await service.stopListening();

    expect(result.text, '早餐两个鸡蛋');
    expect(states, contains(SpeechState.finalizing));
    await subscription.cancel();
    await service.dispose();
  });

  test('late callbacks after cancel do not update the session', () async {
    final engine = _FakeSpeechToText();
    final service = DeviceSpeechRecognitionService(speech: engine);
    final states = <SpeechState>[];
    final subscription = service.stateStream.listen(states.add);

    await service.initialize();
    await service.startListening(onPartial: (_) {});
    await service.cancel();
    engine.emitPartial('迟到的结果');
    await Future<void>.delayed(Duration.zero);

    expect(states.last, SpeechState.idle);
    expect(states, isNot(contains(SpeechState.recognized)));
    await subscription.cancel();
    await service.dispose();
  });

  test('concurrent starts create only one speech session', () async {
    final engine = _FakeSpeechToText();
    final service = DeviceSpeechRecognitionService(speech: engine);

    await service.initialize();
    await Future.wait([
      service.startListening(onPartial: (_) {}),
      service.startListening(onPartial: (_) {}),
    ]);

    expect(engine.listenCalls, 1);
    await service.cancel();
    await service.dispose();
  });

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

  test('recent foods normalize conservative quantity suffixes', () {
    const service = NutritionQuickAccessService();
    final suggestions = service.recentFoods(
      records: [
        ConsumedRecord(
          id: '1',
          name: 'Chicken (100g)',
          p: 20,
          c: 0,
          f: 3,
          kcal: 120,
          mealType: 'breakfast',
          date: '2026-07-12',
        ),
        ConsumedRecord(
          id: '2',
          name: ' Chicken ',
          p: 20,
          c: 0,
          f: 3,
          kcal: 120,
          mealType: 'breakfast',
          date: '2026-07-13',
        ),
      ],
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.usageCount, 2);
  });

  test('recent foods do not merge distinct names', () {
    const service = NutritionQuickAccessService();
    final suggestions = service.recentFoods(
      records: [
        ConsumedRecord(
          id: '1',
          name: 'Apple',
          p: 0,
          c: 14,
          f: 0,
          kcal: 52,
          mealType: 'snack',
          date: '2026-07-13',
        ),
        ConsumedRecord(
          id: '2',
          name: 'Banana',
          p: 1,
          c: 23,
          f: 0,
          kcal: 89,
          mealType: 'snack',
          date: '2026-07-13',
        ),
      ],
    );

    expect(
      suggestions.map((item) => item.displayName),
      containsAll(['Apple', 'Banana']),
    );
  });

  test('recent foods prioritize current meal and usage', () {
    const service = NutritionQuickAccessService();
    final records = List<ConsumedRecord>.generate(
      3,
      (index) => ConsumedRecord(
        id: 'egg-$index',
        name: 'Egg',
        p: 6,
        c: 1,
        f: 5,
        kcal: 70,
        mealType: 'breakfast',
        date: '2026-07-${10 + index}',
      ),
    );
    records.add(
      ConsumedRecord(
        id: 'rice',
        name: 'Rice',
        p: 3,
        c: 28,
        f: 0,
        kcal: 130,
        mealType: 'lunch',
        date: '2026-07-13',
      ),
    );

    final suggestions = service.recentFoods(
      records: records,
      mealType: 'breakfast',
    );

    expect(suggestions.first.displayName, 'Egg');
  });

  test('empty recent history returns an empty list', () {
    const service = NutritionQuickAccessService();

    expect(service.recentFoods(records: const []), isEmpty);
  });

  test('copy plan filters by source date and meal', () {
    const service = NutritionQuickAccessService();
    final plan = service.copyPlan(
      sourceDate: '2026-07-12',
      mealType: 'breakfast',
      records: [
        ConsumedRecord(
          id: '1',
          name: 'Egg',
          p: 6,
          c: 1,
          f: 5,
          kcal: 70,
          mealType: 'breakfast',
          date: '2026-07-12',
        ),
        ConsumedRecord(
          id: '2',
          name: 'Rice',
          p: 3,
          c: 28,
          f: 0,
          kcal: 130,
          mealType: 'lunch',
          date: '2026-07-12',
        ),
      ],
    );

    expect(plan.records, hasLength(1));
    expect(plan.records.single.name, 'Egg');
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
