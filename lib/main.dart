import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'exercise_catalog.dart';
import 'data/builtin_food_database.dart';
import 'dart:async'; // 用于 Timer
import 'package:flutter/services.dart'; // 用于 HapticFeedback 震动
import 'models/consumed_record.dart';
import 'models/daily_macro_stats.dart';
import 'models/exercise_record.dart';
import 'models/food_item.dart';
import 'models/statistics_period.dart';
import 'models/training.dart';
import 'models/progression_target.dart';
import 'models/rest_prescription.dart';
import 'models/water_intake_record.dart';
import 'models/app_snapshot.dart';
import 'models/parsed_diet_item.dart';
import 'models/pending_cloud_deletes.dart';
import 'models/sync_operation.dart';
import 'features/nutrition/nutrition_quick_add_sheet.dart';
import 'features/nutrition/copy_diet_sheet.dart';
import 'features/nutrition/edit_diet_record_sheet.dart';
import 'features/voice_entry/voice_entry_sheet.dart';
import 'features/tracking/weight_picker_sheet.dart';
import 'features/training/exercise_time.dart';
import 'features/training/training_page.dart';
import 'features/training/domain/active_training_session.dart';
import 'features/training/models/exercise_recommendation.dart';
import 'features/training/models/exercise_rest_profile_catalog.dart';
import 'features/training/models/training_template.dart';
import 'features/training/pages/active_training_page.dart';
import 'features/training/pages/training_coverage_page.dart';
import 'features/training/services/training_coverage_calculator.dart';
import 'features/training/services/training_draft_factory.dart';
import 'features/training/services/training_session_engine.dart';
import 'features/training/services/rest_prescription_engine.dart';
import 'features/training/services/training_template_store.dart';
import 'features/training/widgets/training_setup_sheet.dart';
import 'features/training/widgets/training_template_manager_sheet.dart';
import 'features/training/widgets/training_rest_summary.dart';
import 'features/home/home_page.dart';
import 'features/analytics/models/weight_trend.dart';
import 'features/analytics/models/analytics_date_range.dart';
import 'features/analytics/pages/weekly_review_page.dart';
import 'features/analytics/services/trend_weight_calculator.dart';
import 'features/analytics/services/weekly_nutrition_review_calculator.dart';
import 'features/analytics/services/weekly_training_review_calculator.dart';
import 'features/analytics/widgets/weight_trend_summary.dart';
import 'features/history/widgets/history_calendar_day.dart';
import 'features/ai_coach/pages/ai_profile_page.dart';
import 'features/ai_coach/repositories/ai_coach_local_repository.dart';
import 'features/ai_coach/models/ai_coach_state.dart';
import 'features/ai_coach/models/ai_memory.dart';
import 'features/ai_coach/models/ai_suggestion.dart';
import 'features/ai_coach/services/ai_coach_scenario_service.dart';
import 'features/ai_coach/services/ai_suggestion_service.dart';
import 'features/ai_coach/services/training_ai_action_service.dart';
import 'features/ai_coach/widgets/ai_suggestion_action_sheet.dart';
import 'features/profile/models/profile_summary.dart';
import 'features/profile/pages/account_center_pages.dart';
import 'features/profile/pages/profile_page.dart';
import 'features/profile/services/account_deletion_service.dart';
import 'features/profile/services/json_file_delivery.dart';
import 'features/profile/services/profile_summary_service.dart';
import 'features/profile/services/user_data_export_service.dart';
import 'widgets/goat_page_header.dart';
import 'features/water/water_tracking_page.dart';
import 'repositories/nutrition_repository.dart';
import 'repositories/water_tracking_repository.dart';
import 'repositories/local_training_repository.dart';
import 'repositories/in_memory_training_repository.dart';
import 'services/cloud_sync_service.dart';
import 'services/local_storage_service.dart';
import 'services/nutrition_ai_service.dart';
import 'services/supabase_nutrition_ai_service.dart';
import 'services/speech_recognition_service.dart';
import 'services/nutrition_quick_access_service.dart';
import 'services/sync_queue_service.dart';
import 'services/sync_diagnostics.dart';

export 'models/consumed_record.dart';
export 'models/daily_macro_stats.dart';
export 'models/exercise_record.dart';
export 'models/food_item.dart';
export 'models/statistics_period.dart';
export 'models/training.dart';

const bool enableSystemSpeechRecognition = bool.fromEnvironment(
  'ENABLE_SYSTEM_SPEECH',
  defaultValue: false,
);

final GlobalKey<ScaffoldMessengerState> _rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Supabase 官方版初始化 ---
  await Supabase.initialize(
    url: 'https://anqzlobatxkpeyimwbrv.supabase.co',
    publishableKey: 'sb_publishable_gSpKJMeZY2ZNZfcGC5xQpw_f19OQ15X',
  );

  runApp(const GoatApp());
}

// ============================================================================
// 2. 核心应用与全局主题
// ============================================================================
class GoatApp extends StatelessWidget {
  const GoatApp({super.key});

  static const TextStyle squareStyle = TextStyle(
    fontFamily: 'monospace',
    letterSpacing: 0.5,
    fontWeight: FontWeight.w600,
  );
  static const Color marsGreen = Color(0xFF008C8C);
  static const Color deepSeekBlue = Color(0xFF4D6BFE);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _rootMessengerKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        colorSchemeSeed: marsGreen,
        textTheme: const TextTheme(
          bodyMedium: squareStyle,
          bodyLarge: squareStyle,
          titleLarge: squareStyle,
        ),
      ),
      home: const MainTabController(),
    );
  }
}

// ============================================================================
// 3. 全局状态控制器
// ============================================================================
class MainTabController extends StatefulWidget {
  const MainTabController({super.key});
  @override
  State<MainTabController> createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController>
    with WidgetsBindingObserver
    implements NutritionRepository, WaterTrackingRepository {
  final supabase = Supabase.instance.client;
  late final CloudSyncService _cloudSyncService = CloudSyncService(supabase);
  final DeviceSpeechRecognitionService _speechService =
      DeviceSpeechRecognitionService();
  late final NutritionAiService _nutritionAiService =
      _createNutritionAiService();
  final NutritionQuickAccessService _nutritionQuickAccessService =
      const NutritionQuickAccessService();
  LocalStorageService? _storage;
  String _activeNamespace = 'guest';
  String? _activeUserId;
  StreamSubscription<AuthState>? _authSubscription;
  bool _cloudSyncPending = false;
  ConsumedRecord? _undoDietRecord;
  int _undoDietIndex = 0;
  bool _guestMergePending = false;
  String _dailyAiTip = "正在为您生成专属健康建议...";
  bool _isAiTipLoading = false;
  DateTime _calendarMonth = DateTime.now();
  bool _isHistoryDetailExpanded = false;
  final String deepSeekApiKey = const String.fromEnvironment(
    'DEEPSEEK_API_KEY',
  );
  bool get _allowDirectDebugAi =>
      kDebugMode &&
      const bool.fromEnvironment('GOAT_DEBUG_DIRECT_AI', defaultValue: false) &&
      deepSeekApiKey.trim().isNotEmpty;
  late String _currentAiTip;
  String aiDismissedDate = "";
  bool _isAppLoading = true;

  // ==========================================
  // 🌟 核心新增：组间休息倒计时状态与方法
  // ==========================================
  int _restTimeRemaining = 0; // 剩余秒数
  int _restTimeTotal = 1; // 总秒数（用于计算进度条比例）
  Timer? _restTimer; // 定时器对象

  void _startRestTimer(int seconds) {
    _restTimer?.cancel(); // 如果已有定时器，先关掉
    setState(() {
      _restTimeTotal = seconds;
      _restTimeRemaining = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTimeRemaining > 1) {
        setState(() => _restTimeRemaining--);
      } else {
        timer.cancel();
        setState(() => _restTimeRemaining = 0);
        // 🌟 震动反馈：休息结束，该练了！
        HapticFeedback.heavyImpact();
      }
    });
  }

  final List<String> aiTips = [
    "今日建议：早起水分充足，午餐建议增加 50g 优质蛋白质（如鸡胸肉）。",
    "健康贴士：运动后30分钟内补充碳水和蛋白质，促进肌肉合成。",
    "饮食小贴士：多吃深色蔬菜（如菠菜、西兰花），有助于减轻身体炎症。",
    "补水提示：感到口渴时身体其实已经缺水，记得养成定时喝水的好习惯。",
    "减脂干货：不要完全拒绝脂肪，适量摄入优质脂肪对激素合成至关重要。",
  ];

  // --- 基础个人信息 ---
  String gender = "男";
  int birthYear = 2000;
  int birthMonth = 1;
  int birthDay = 1;
  double height = 175.0;
  double currentWeight = 70.0;

  int _currentIndex = 0;
  List<FoodItem> foodDatabase = [];
  List<ConsumedRecord> allConsumedItems = [];
  List<ExerciseRecord> allExerciseItems = [];
  List<TrainingSession> allTrainingSessions = [];
  ActiveTrainingSession? _activeTrainingSession;
  List<WaterIntakeRecord> waterIntakeRecords = [];
  Map<String, double> dailyWeight = {};
  List<String> searchHistory = [];
  PendingCloudDeletes _pendingCloudDeletes = const PendingCloudDeletes.empty();
  SyncQueueService _syncQueue = SyncQueueService();

  double targetP = 150, targetC = 200, targetF = 60, targetKcal = 2000;
  int resetHour = 0;
  bool isCyclingMode = false;
  int selectedDay = DateTime.now().weekday;

  late String viewDateStr;
  bool _isSearching = false;

  String get todayStr {
    DateTime now = DateTime.now();
    if (now.hour < resetHour) now = now.subtract(const Duration(days: 1));
    return now.toString().substring(0, 10);
  }

  bool get isToday => viewDateStr == todayStr;

  String _formatWeight(double value) => formatWeightValue(value);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    viewDateStr = todayStr;
    _currentAiTip = aiTips[math.Random().nextInt(aiTips.length)];
    _authSubscription = supabase.auth.onAuthStateChange.listen((event) {
      unawaited(_handleAuthChange(event.session?.user));
    });
    _initUserAndData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_speechService.cancel());
    } else {
      unawaited(_retryCloudSync());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _restTimer?.cancel();
    unawaited(_speechService.dispose());
    if (_nutritionAiService case final DeepSeekNutritionAiService service) {
      service.dispose();
    }
    super.dispose();
  }

  Future<void> _handleAuthChange(User? user) async {
    if (_storage == null) return;
    final nextUserId = user == null || user.isAnonymous ? null : user.id;
    if (nextUserId == _activeUserId) return;
    await _saveLocalPreferencesOnly();
    _activeUserId = nextUserId;
    _activeNamespace = _storage!.namespaceForUser(_activeUserId);
    await _mergeGuestDataIfNeeded();
    await _loadLocalData();
    if (mounted) setState(() {});
    if (_activeUserId != null) unawaited(_connectAndSyncCloud());
  }

  // 🌟 AI 建议获取函数
  bool _isHistoryExpanded = false;
  StatisticsPeriod _statisticsPeriod = StatisticsPeriod.week;

  Future<void> _fetchDailyAiTip() async {
    if (_isAiTipLoading) return;
    if (mounted) setState(() => _isAiTipLoading = true);
    if (!_allowDirectDebugAi) {
      if (mounted) setState(() => _isAiTipLoading = false);
      return;
    }

    // 🌟 这里使用的是你原本正确的 _getDailyStats 和 gender、height 等变量
    final stats = _getDailyStats(viewDateStr);
    final prompt =
        "我是$gender，身高${height.toInt()}cm，体重$currentWeight kg。今日目标热量${targetKcal.toInt()}kcal。目前已摄入${stats.kcalIn.toInt()}kcal，运动消耗${stats.burn.toInt()}kcal。请给一条50字以内的专业健康建议。";

    try {
      final response = await http
          .post(
            Uri.parse('https://api.deepseek.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $deepSeekApiKey',
            },
            body: jsonEncode({
              "model": "deepseek-chat",
              "messages": [
                {"role": "system", "content": "你是一个严谨的营养师，说话简练。"},
                {"role": "user", "content": prompt},
              ],
              "temperature": 0.7,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _currentAiTip = data['choices'][0]['message']['content'];
          });
        }
      }
    } catch (e) {
      debugPrint("AI建议获取失败: $e");
    } finally {
      if (mounted) setState(() => _isAiTipLoading = false);
    }
  }

  Future<void> _initUserAndData() async {
    try {
      _storage = await LocalStorageService.create();
      await _storage!.migrateLegacyGuestData();
      final user = supabase.auth.currentUser;
      _activeUserId = user != null && !user.isAnonymous ? user.id : null;
      _activeNamespace = _storage!.namespaceForUser(_activeUserId);
      await _mergeGuestDataIfNeeded();
      await _loadLocalData();
    } catch (e) {
      debugPrint('本地数据初始化失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAppLoading = false;
        });
      }
    }

    // 网络不可用时也必须允许用户进入 App，云端连接在后台完成。
    unawaited(_connectAndSyncCloud());
  }

  Future<void> _mergeGuestDataIfNeeded() async {
    if (_activeUserId == null || _storage == null) return;
    final guestNamespace = _storage!.namespaceForUser(null);
    final guest = _storage!.load(guestNamespace);
    if (guest != null && guest.hasData) {
      final userData = _storage!.load(_activeNamespace) ?? AppSnapshot.empty();
      final merged = userData.merge(guest);
      await _storage!.save(_activeNamespace, merged);
      _guestMergePending = true;
      _cloudSyncPending = true;
    }

    final guestAiRepository = AiCoachLocalRepository(
      preferences: _storage!.prefs,
      namespace: guestNamespace,
    );
    final guestAiState = guestAiRepository.load();
    if (guestAiState.memories.isNotEmpty ||
        guestAiState.suggestions.isNotEmpty ||
        guestAiState.feedback.isNotEmpty) {
      final userAiRepository = AiCoachLocalRepository(
        preferences: _storage!.prefs,
        namespace: _activeNamespace,
      );
      await userAiRepository.mergeFrom(guestAiState);
      await guestAiRepository.clear();
    }
  }

  Future<void> _connectAndSyncCloud() async {
    const authTimeout = Duration(seconds: 8);
    const syncTimeout = Duration(seconds: 15);

    try {
      if (supabase.auth.currentSession == null) {
        await supabase.auth.signInAnonymously().timeout(authTimeout);
      }
      await _syncWithCloud().timeout(syncTimeout);
      if (supabase.auth.currentUser?.isAnonymous == false) {
        await _saveData();
      }
    } on TimeoutException {
      debugPrint('云端连接超时，当前继续使用本地数据');
    } catch (e) {
      debugPrint('云端连接失败，当前继续使用本地数据: $e');
    }
  }

  Future<void> _loadLocalData() async {
    final snapshot = _storage?.load(_activeNamespace) ?? AppSnapshot.empty();
    _applySnapshot(snapshot);
  }

  Future<void> _saveLocalPreferencesOnly() async {
    final storage = _storage;
    if (storage == null) return;
    await storage.save(_activeNamespace, _snapshotFromState());
  }

  Future<void> _saveData() async {
    final snapshot = _snapshotFromState();
    final user = supabase.auth.currentUser;
    var readyOperations = const <SyncOperation>[];
    if (user != null &&
        !user.isAnonymous &&
        _cloudSyncService.versionedSyncEnabled) {
      _syncQueue.enqueueSnapshot(userId: user.id, snapshot: snapshot);
      readyOperations = _syncQueue.ready();
      for (final operation in readyOperations) {
        SyncDiagnostics.queue(
          operationId: operation.operationId,
          entityType: operation.entityType,
          queueLength: _syncQueue.operations.length,
          retryCount: operation.retryCount,
        );
      }
    }
    await _saveLocalPreferencesOnly();
    if (user == null || user.isAnonymous) return;

    try {
      final processedDeletes = await _cloudSyncService
          .syncSnapshot(
            user: user,
            snapshot: snapshot,
            operations: readyOperations,
          )
          .timeout(const Duration(seconds: 15));
      _pendingCloudDeletes = _pendingCloudDeletes.without(processedDeletes);
      if (_cloudSyncService.versionedSyncEnabled) {
        for (final operation in readyOperations) {
          _syncQueue.markSucceeded(operation.operationId);
        }
        _syncQueue.advanceCursor(DateTime.now().toUtc());
      }
      await _storage?.save(_activeNamespace, _snapshotFromState());
      if (_guestMergePending && _storage != null) {
        await _storage!.clearNamespace(_storage!.namespaceForUser(null));
        _guestMergePending = false;
      }
      _cloudSyncPending = false;
    } catch (e) {
      if (_cloudSyncService.versionedSyncEnabled) {
        for (final operation in _syncQueue.ready()) {
          _syncQueue.markFailed(operation.operationId);
        }
      }
      await _saveLocalPreferencesOnly();
      _cloudSyncPending = true;
      debugPrint('云端保存失败，保留本地待同步状态: $e');
    }
  }

  Future<void> _retryCloudSync() async {
    if (!_cloudSyncPending) return;
    await _saveData();
  }

  Future<void> _syncWithCloud() async {
    final user = supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final cloudSnapshot = await _cloudSyncService.fetchSnapshot(
        user,
        lastSyncedAt: _cloudSyncService.versionedSyncEnabled
            ? _syncQueue.cursor.lastSyncedAt
            : null,
      );
      if (cloudSnapshot == null) return;
      final localSnapshot =
          _storage?.load(_activeNamespace) ?? AppSnapshot.empty();
      final hasPendingVersionedWork =
          _cloudSyncService.versionedSyncEnabled &&
          _syncQueue.operations.isNotEmpty;
      final merged =
          (hasPendingVersionedWork
                  ? localSnapshot.merge(cloudSnapshot)
                  : cloudSnapshot.merge(localSnapshot))
              .applyDeletes(cloudSnapshot.pendingCloudDeletes);
      _applySnapshot(merged);
      if (_cloudSyncService.versionedSyncEnabled) {
        _syncQueue.advanceCursor(DateTime.now().toUtc());
      }
      await _saveLocalPreferencesOnly();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("云端拉取失败: $e");
    }
  }

  AppSnapshot _snapshotFromState() => AppSnapshot(
    gender: gender,
    birthYear: birthYear,
    birthMonth: birthMonth,
    birthDay: birthDay,
    height: height,
    currentWeight: currentWeight,
    searchHistory: List.unmodifiable(searchHistory),
    targetP: targetP,
    targetC: targetC,
    targetF: targetF,
    targetKcal: targetKcal,
    resetHour: resetHour,
    aiDismissedDate: aiDismissedDate,
    foods: List.unmodifiable(foodDatabase),
    consumed: List.unmodifiable(allConsumedItems),
    exercises: List.unmodifiable(allExerciseItems),
    training: List.unmodifiable(allTrainingSessions),
    activeTrainingSession: _activeTrainingSession,
    waterRecords: List.unmodifiable(waterIntakeRecords),
    water: Map.unmodifiable(waterTotals(waterIntakeRecords)),
    weight: Map.unmodifiable(dailyWeight),
    pendingCloudDeletes: _pendingCloudDeletes,
    syncOperations: List.unmodifiable(_syncQueue.operations),
    syncCursor: _syncQueue.cursor,
  );

  void _applySnapshot(AppSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      gender = snapshot.gender;
      birthYear = snapshot.birthYear;
      birthMonth = snapshot.birthMonth;
      birthDay = snapshot.birthDay;
      height = snapshot.height;
      currentWeight = snapshot.currentWeight;
      searchHistory = [...snapshot.searchHistory];
      targetP = snapshot.targetP;
      targetC = snapshot.targetC;
      targetF = snapshot.targetF;
      targetKcal = snapshot.targetKcal;
      resetHour = snapshot.resetHour;
      aiDismissedDate = snapshot.aiDismissedDate;
      foodDatabase = [...snapshot.foods];
      allConsumedItems = [...snapshot.consumed];
      allExerciseItems = [...snapshot.exercises];
      allTrainingSessions = [...snapshot.training];
      _activeTrainingSession = snapshot.activeTrainingSession;
      waterIntakeRecords = [...snapshot.waterRecords];
      dailyWeight = {...snapshot.weight};
      _pendingCloudDeletes = snapshot.pendingCloudDeletes;
      _syncQueue = SyncQueueService.fromSnapshot(
        snapshot,
        userId: _activeUserId ?? 'guest',
      );
    });
  }

  NutritionAiService _createNutritionAiService() {
    const useDirectDebugAi = bool.fromEnvironment(
      'GOAT_DEBUG_DIRECT_AI',
      defaultValue: false,
    );
    if (kDebugMode && useDirectDebugAi && deepSeekApiKey.trim().isNotEmpty) {
      return DeepSeekNutritionAiService(apiKey: deepSeekApiKey);
    }
    return SupabaseNutritionAiService(client: supabase);
  }

  void _queueFoodDelete(String id) {
    _pendingCloudDeletes = _pendingCloudDeletes.copyWith(
      foodIds: {..._pendingCloudDeletes.foodIds, id},
    );
  }

  void _queueDietDelete(String id) {
    _pendingCloudDeletes = _pendingCloudDeletes.copyWith(
      dietRecordIds: {..._pendingCloudDeletes.dietRecordIds, id},
    );
  }

  void _queueExerciseDelete(String id) {
    _pendingCloudDeletes = _pendingCloudDeletes.copyWith(
      exerciseRecordIds: {..._pendingCloudDeletes.exerciseRecordIds, id},
    );
  }

  void _queueWaterDelete(String id) {
    _pendingCloudDeletes = _pendingCloudDeletes.copyWith(
      waterRecordIds: {..._pendingCloudDeletes.waterRecordIds, id},
    );
  }

  List<WaterIntakeRecord> _waterRecordsForDate(String date) {
    final records =
        waterIntakeRecords.where((record) => record.date == date).toList()
          ..sort((a, b) {
            final aTime =
                a.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aTime.compareTo(bTime);
          });
    return records;
  }

  int _waterTotalForDate(String date) {
    return _waterRecordsForDate(
      date,
    ).fold(0, (total, record) => total + record.amountMl);
  }

  @override
  List<WaterIntakeRecord> waterRecordsForDate(String date) =>
      _waterRecordsForDate(date);

  @override
  Future<void> addWaterRecord(WaterIntakeRecord record) async {
    if (!mounted || record.amountMl <= 0) return;
    setState(() => waterIntakeRecords.add(record));
    await _saveData();
  }

  @override
  Future<void> updateWaterRecord(WaterIntakeRecord record) async {
    if (!mounted) return;
    final index = waterIntakeRecords.indexWhere((item) => item.id == record.id);
    if (index == -1) return;
    setState(() => waterIntakeRecords[index] = record);
    await _saveData();
  }

  @override
  Future<void> deleteWaterRecord(String recordId) async {
    if (!mounted) return;
    final index = waterIntakeRecords.indexWhere((item) => item.id == recordId);
    if (index == -1) return;
    setState(() => waterIntakeRecords.removeAt(index));
    _queueWaterDelete(recordId);
    await _saveData();
  }

  @override
  Future<void> addRecords(List<ParsedDietItem> items) async {
    if (items.isEmpty) return;
    if (!mounted) return;
    final records = items
        .map(
          (item) => ConsumedRecord(
            id: '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1000)}',
            name: item.name,
            p: item.protein,
            c: item.carbs,
            f: item.fat,
            kcal: item.kcal,
            mealType: item.mealType,
            date: viewDateStr,
            amount: item.amount,
            unit: item.unit,
          ),
        )
        .toList();
    setState(() => allConsumedItems.insertAll(0, records));
    await _saveData();
  }

  @override
  List<ConsumedRecord> recordsForDate(String date) =>
      allConsumedItems.where((record) => record.date == date).toList();

  @override
  Future<void> addConsumedRecords(List<ConsumedRecord> records) async {
    if (records.isEmpty || !mounted) return;
    final copies = records
        .map(
          (record) => ConsumedRecord(
            id: '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1000)}',
            name: record.name,
            p: record.p,
            c: record.c,
            f: record.f,
            kcal: record.kcal,
            mealType: record.mealType,
            date: record.date,
            amount: record.amount,
            unit: record.unit,
          ),
        )
        .toList();
    setState(() => allConsumedItems.insertAll(0, copies));
    await _saveData();
  }

  @override
  Future<void> updateRecord(ConsumedRecord record) async {
    final index = allConsumedItems.indexWhere((item) => item.id == record.id);
    if (index == -1 || !mounted) return;
    setState(() => allConsumedItems[index] = record);
    await _saveData();
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    final index = allConsumedItems.indexWhere((item) => item.id == recordId);
    if (index == -1) return;
    final record = allConsumedItems[index];
    _undoDietRecord = record;
    _undoDietIndex = index;
    setState(() {
      allConsumedItems = allConsumedItems
          .where((item) => item.id != recordId)
          .toList();
    });
    _queueDietDelete(record.id);
    await _saveData();
    _rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('已删除该记录'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => unawaited(_undoLastDietDelete()),
          ),
        ),
      );
  }

  Future<void> _undoLastDietDelete() async {
    final record = _undoDietRecord;
    if (record == null || !mounted) return;
    _undoDietRecord = null;
    _pendingCloudDeletes = _pendingCloudDeletes.copyWith(
      dietRecordIds: {..._pendingCloudDeletes.dietRecordIds}..remove(record.id),
    );
    final index = _undoDietIndex.clamp(0, allConsumedItems.length);
    setState(() => allConsumedItems.insert(index, record));
    await _saveData();
  }

  @override
  Future<void> restoreRecord(ConsumedRecord record) async {
    _pendingCloudDeletes = _pendingCloudDeletes.copyWith(
      dietRecordIds: {..._pendingCloudDeletes.dietRecordIds}..remove(record.id),
    );
    if (!mounted) return;
    setState(() => allConsumedItems.insert(0, record));
    await _saveData();
  }

  @override
  Future<void> replaceRecordsForOperation(List<ConsumedRecord> records) async {
    if (!mounted) return;
    setState(() {
      allConsumedItems.insertAll(0, records);
    });
    await _saveData();
  }

  DailyMacroStats _getDailyStats(String date) {
    final consumed = allConsumedItems.where((i) => i.date == date);
    final exercise = allExerciseItems.where((i) => i.date == date);
    return DailyMacroStats(
      kcalIn: consumed.fold(0, (sum, i) => sum + i.kcal),
      p: consumed.fold(0, (sum, i) => sum + i.p),
      c: consumed.fold(0, (sum, i) => sum + i.c),
      f: consumed.fold(0, (sum, i) => sum + i.f),
      burn: exercise.fold(0, (sum, i) => sum + i.kcal),
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<DateTime> _statisticsDates() {
    final days = _statisticsPeriod == StatisticsPeriod.week ? 7 : 30;
    final endDate = DateUtils.dateOnly(
      DateTime.tryParse(viewDateStr) ?? DateTime.now(),
    );
    return List<DateTime>.generate(
      days,
      (index) => endDate.subtract(Duration(days: days - index - 1)),
    );
  }

  DailyMacroStats _getPeriodStats(List<DateTime> dates) {
    final dateKeys = dates.map(_dateKey).toSet();
    final consumed = allConsumedItems.where(
      (item) => dateKeys.contains(item.date),
    );
    final exercise = allExerciseItems.where(
      (item) => dateKeys.contains(item.date),
    );
    return DailyMacroStats(
      kcalIn: consumed.fold(0, (sum, item) => sum + item.kcal),
      p: consumed.fold(0, (sum, item) => sum + item.p),
      c: consumed.fold(0, (sum, item) => sum + item.c),
      f: consumed.fold(0, (sum, item) => sum + item.f),
      burn: exercise.fold(0, (sum, item) => sum + item.kcal),
    );
  }

  // ============================================================================
  // 新增：力量训练主页构建逻辑 (必须放在 _MainTabControllerState 内部)
  // ============================================================================
  Widget _buildTrainingPage() {
    return TrainingPage(
      sessions: allTrainingSessions,
      businessDate: viewDateStr,
      activeSession: _activeTrainingSession,
      onResumeTraining: _activeTrainingSession == null
          ? null
          : _openActiveTraining,
      onStartTraining: _showTrainingSetup,
      onUsePplTemplate: () =>
          _startFastTraining(name: 'PPL-推力日', exerciseName: '杠铃平板卧推'),
      onUseFullBodyTemplate: () =>
          _startFastTraining(name: '全身循环燃脂', exerciseName: '杠铃深蹲'),
      onViewHistory: _showTrainingHistorySheet,
      onManageTemplates: _showTrainingTemplateManager,
      onOpenWeeklyReview: _showWeeklyReviewPage,
      onOpenCoverage: _showTrainingCoveragePage,
    );
  }

  LocalTrainingRepository? _localTrainingRepository() {
    final storage = _storage;
    if (storage == null) return null;
    return LocalTrainingRepository(
      storage: storage,
      namespace: _activeNamespace,
    );
  }

  List<WeightRecord> _weightRecords() => dailyWeight.entries
      .map((entry) {
        final date = DateTime.tryParse(entry.key);
        return date == null
            ? null
            : WeightRecord(recordedAt: date, weightKg: entry.value);
      })
      .whereType<WeightRecord>()
      .toList(growable: false);

  WeightTrend _weightTrendFor(DateTime anchorDate) =>
      const TrendWeightCalculator().calculate(
        records: _weightRecords(),
        anchorDate: anchorDate,
      );

  List<AiMemoryItem> _activeAiMemories() {
    final storage = _storage;
    if (storage == null) return const [];
    return AiCoachLocalRepository(
      preferences: storage.prefs,
      namespace: _activeNamespace,
    ).load().memories.where((item) => item.isUsableInContext).toList();
  }

  String? _profileMemory(AiProfileCategory category) => _activeAiMemories()
      .where((item) => item.category == category)
      .map((item) => item.value)
      .firstOrNull;

  Future<void> _showWeeklyReviewPage() async {
    final anchor = DateUtils.dateOnly(
      DateTime.tryParse(viewDateStr) ?? DateTime.now(),
    );
    final weights = _weightRecords();
    final training = const WeeklyTrainingReviewCalculator().calculate(
      completedSessions: allTrainingSessions,
      anchorDate: anchor,
    );
    final nutrition = const WeeklyNutritionReviewCalculator().calculate(
      records: allConsumedItems,
      weightRecords: weights,
      anchorDate: anchor,
    );
    final coverage = const TrainingCoverageCalculator().calculateHistory(
      completedSessions: allTrainingSessions,
      dateRange: AnalyticsDateRange(
        start: anchor.subtract(const Duration(days: 6)),
        end: anchor,
      ),
    );
    final template = _localTrainingTemplateStore()?.load().firstOrNull;
    final generatedWeeklySuggestion = template == null
        ? null
        : _buildWeeklyRestSuggestion(template, anchor);
    final aiRepository = _aiCoachRepository();
    final existingWeeklySuggestion =
        generatedWeeklySuggestion == null || aiRepository == null
        ? null
        : aiRepository
              .load()
              .suggestions
              .where((item) => item.id == generatedWeeklySuggestion.id)
              .firstOrNull;
    final weeklySuggestion =
        existingWeeklySuggestion ?? generatedWeeklySuggestion;
    if (generatedWeeklySuggestion != null &&
        existingWeeklySuggestion == null &&
        aiRepository != null) {
      await aiRepository.saveSuggestion(generatedWeeklySuggestion);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyReviewPage(
          training: training,
          nutrition: nutrition,
          coverage: coverage,
          onOpenCoverage: _showTrainingCoveragePage,
          coachMemories: _activeAiMemories(),
          trainingGoal: _profileMemory(AiProfileCategory.trainingGoal),
          coachSuggestions: [
            if (weeklySuggestion != null &&
                (weeklySuggestion.status == AiSuggestionStatus.proposed ||
                    weeklySuggestion.status == AiSuggestionStatus.applyFailed))
              weeklySuggestion,
          ],
          onOpenSuggestion: weeklySuggestion == null || template == null
              ? null
              : (suggestion) => unawaited(
                  _handleWeeklySuggestion(
                    suggestion,
                    template,
                    exerciseName: _exerciseNameById(
                      suggestion.proposedAction?.payload['exerciseId']
                              as String? ??
                          '',
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  AiCoachLocalRepository? _aiCoachRepository() {
    final storage = _storage;
    if (storage == null) return null;
    return AiCoachLocalRepository(
      preferences: storage.prefs,
      namespace: _activeNamespace,
    );
  }

  AiSuggestion? _buildWeeklyRestSuggestion(
    TrainingTemplate template,
    DateTime anchor,
  ) {
    final exerciseId = template.exerciseIds.firstOrNull;
    if (exerciseId == null ||
        template.restFor(exerciseId).mode == RestPrescriptionMode.fixed) {
      return null;
    }
    final recommendation = const RestPrescriptionEngine().recommend(
      RestPrescriptionRequest(
        currentProfile: ExerciseRestProfileCatalog.find(exerciseId),
      ),
    );
    return const AiCoachScenarioService().restSuggestion(
      id: 'weekly-rest-${anchor.year}-${anchor.month}-${anchor.day}-${template.id}-$exerciseId',
      templateId: template.id,
      exerciseId: exerciseId,
      exerciseName: _exerciseNameById(exerciseId),
      fixedSeconds: recommendation.recommendedSeconds,
      createdAt: anchor,
    );
  }

  String _exerciseNameById(String exerciseId) =>
      exerciseCatalog
          .where((item) => item.id == exerciseId)
          .map((item) => item.name)
          .firstOrNull ??
      exerciseId;

  Future<void> _handleWeeklySuggestion(
    AiSuggestion suggestion,
    TrainingTemplate template, {
    required String exerciseName,
  }) async {
    final repository = _aiCoachRepository();
    final templateStore = _localTrainingTemplateStore();
    final action = suggestion.proposedAction;
    if (repository == null || templateStore == null || action == null) return;
    final seconds = (action.payload['fixedSeconds'] as num?)?.toInt();
    if (seconds == null) return;
    final decision = await AiSuggestionActionSheet.show(
      context,
      suggestion: suggestion,
      currentLabel: 'GOAT 推荐（随组状态动态计算）',
      updatedLabel:
          '固定 ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
      impactLabel: '训练方案“${template.name}”中的 $exerciseName；当前训练快照不变',
    );
    if (decision == null || !mounted) return;
    if (!decision.confirmed) {
      final feedbackType =
          decision.feedbackType ?? SuggestionFeedbackType.dismissed;
      final rejected = feedbackType != SuggestionFeedbackType.dismissed;
      final dismissed = const AiSuggestionTransitionService().transition(
        suggestion,
        rejected ? AiSuggestionStatus.rejected : AiSuggestionStatus.dismissed,
      );
      await repository.saveSuggestion(dismissed);
      await repository.recordFeedback(
        SuggestionFeedback(
          suggestionId: suggestion.id,
          decision: rejected
              ? SuggestionDecision.rejected
              : SuggestionDecision.dismissed,
          reasonCode: switch (feedbackType) {
            SuggestionFeedbackType.notForMe =>
              SuggestionRejectionReason.notSuitable,
            SuggestionFeedbackType.inaccurateData =>
              SuggestionRejectionReason.inaccurateData,
            SuggestionFeedbackType.disliked =>
              SuggestionRejectionReason.dislikeSuggestion,
            _ => null,
          },
          feedbackType: feedbackType,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }
    final actionService = TrainingAiActionService(templateStore: templateStore);
    final result = await const AiSuggestionApplicationService().apply(
      suggestion: suggestion,
      userConfirmed: true,
      modifiedAction: decision.modifiedAction,
      validate: actionService.validate,
      persist: actionService.apply,
      onTransition: repository.saveSuggestion,
    );
    await repository.saveSuggestion(result);
    await repository.recordFeedback(
      SuggestionFeedback(
        suggestionId: suggestion.id,
        decision: decision.modifiedAction == null
            ? SuggestionDecision.accepted
            : SuggestionDecision.modified,
        modifiedAction: decision.modifiedAction,
        feedbackType: result.status == AiSuggestionStatus.applied
            ? SuggestionFeedbackType.helpful
            : SuggestionFeedbackType.inaccurateData,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.status == AiSuggestionStatus.applied
              ? '建议已应用；当前训练快照保持不变'
              : result.failureMessage ?? '建议应用失败，原数据未改变',
        ),
      ),
    );
  }

  void _showTrainingCoveragePage() {
    final anchor = DateUtils.dateOnly(
      DateTime.tryParse(viewDateStr) ?? DateTime.now(),
    );
    final calculator = const TrainingCoverageCalculator();
    final active = _activeTrainingSession;
    final currentCoverage = active == null
        ? null
        : calculator.calculateSession(
            session: active.draft,
            isActiveSession: true,
          );
    final todaySessions = allTrainingSessions
        .where((session) => session.date == viewDateStr)
        .where((session) => session.id != active?.draft.id)
        .toList();
    if (active?.draft.date == viewDateStr) todaySessions.add(active!.draft);
    final todayCoverage = calculator.calculateSessions(
      sessions: todaySessions,
      activeSessionIds: active == null ? const {} : {active.draft.id},
    );
    final weeklySessions = allTrainingSessions.where((session) {
      final date = DateTime.tryParse(session.date);
      return date != null &&
          AnalyticsDateRange(
            start: anchor.subtract(const Duration(days: 6)),
            end: anchor,
          ).contains(date) &&
          session.id != active?.draft.id;
    }).toList();
    if (active != null) {
      final activeDate = DateTime.tryParse(active.draft.date);
      if (activeDate != null &&
          AnalyticsDateRange(
            start: anchor.subtract(const Duration(days: 6)),
            end: anchor,
          ).contains(activeDate)) {
        weeklySessions.add(active.draft);
      }
    }
    final weeklyCoverage = calculator.calculateSessions(
      sessions: weeklySessions,
      activeSessionIds: active == null ? const {} : {active.draft.id},
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrainingCoveragePage(
          currentCoverage: currentCoverage,
          todayCoverage: todayCoverage,
          weeklyCoverage: weeklyCoverage,
          catalog: exerciseCatalog,
          activeSession: active?.draft,
          coachMemories: _activeAiMemories(),
          onApplyRecommendation: active == null
              ? null
              : _adoptCoverageRecommendation,
        ),
      ),
    );
  }

  Future<void> _adoptCoverageRecommendation(
    ExerciseRecommendationResult recommendation,
  ) async {
    final repository = _localTrainingRepository();
    final active = _activeTrainingSession;
    if (repository == null || active == null) return;
    final definition = recommendation.exercise;
    final updated = await TrainingSessionEngine(repository: repository)
        .adoptRecommendedExercise(
          recommendation: TrainingExercise(
            exerciseId: definition.id,
            exerciseName: definition.name,
            bodyPart: definition.bodyPart,
            sets: [
              for (var index = 0; index < 4; index++)
                SetRecord(id: '${active.id}-${definition.id}-${index + 1}'),
            ],
          ),
        );
    if (mounted) setState(() => _activeTrainingSession = updated);
  }

  TrainingTemplateStore? _localTrainingTemplateStore() {
    final storage = _storage;
    if (storage == null) return null;
    return TrainingTemplateStore(
      preferences: storage.prefs,
      namespace: _activeNamespace,
    );
  }

  Future<void> _showTrainingSetup() async {
    if (_activeTrainingSession != null) {
      _openActiveTraining();
      return;
    }
    final selection = await TrainingSetupSheet.show(
      context,
      catalog: exerciseCatalog,
    );
    if (selection == null || !mounted) return;
    await _startTraining(
      name: selection.sessionName,
      exercises: selection.exercises,
    );
  }

  Future<void> _showTrainingTemplateManager() async {
    final store = _localTrainingTemplateStore();
    if (store == null) return;
    final template = await TrainingTemplateManagerSheet.show(
      context,
      catalog: exerciseCatalog,
      store: store,
    );
    if (template == null || !mounted) return;
    final exercises = template.resolveExercises(exerciseCatalog);
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该方案中没有可用动作')));
      return;
    }
    await _startTraining(
      name: template.name,
      exercises: exercises,
      progressionTargets: template.progressionTargets,
      restPrescriptions: template.restPrescriptions,
    );
  }

  Future<void> _startFastTraining({
    required String name,
    required String exerciseName,
  }) async {
    ExerciseDefinition? definition;
    for (final exercise in exerciseCatalog) {
      if (exercise.name == exerciseName) {
        definition = exercise;
        break;
      }
    }
    final selectedDefinition = definition;
    if (selectedDefinition == null) return;
    await _startTraining(name: name, exercises: [selectedDefinition]);
  }

  Future<void> _startTraining({
    required String name,
    required List<ExerciseDefinition> exercises,
    Map<String, ProgressionTarget> progressionTargets = const {},
    Map<String, RestPrescription> restPrescriptions = const {},
  }) async {
    if (_activeTrainingSession != null) {
      _openActiveTraining();
      return;
    }
    if (exercises.isEmpty) return;
    final repository = _localTrainingRepository();
    if (repository == null) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final draft = const TrainingDraftFactory().create(
      id: timestamp,
      name: name,
      date: viewDateStr,
      exercises: exercises,
      progressionTargets: progressionTargets,
      restPrescriptions: restPrescriptions,
    );
    try {
      final active = await TrainingSessionEngine(
        repository: repository,
      ).startSession(activeSessionId: 'active-$timestamp', draft: draft);
      if (!mounted) return;
      setState(() => _activeTrainingSession = active);
      _openActiveTraining();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('训练暂未开始，请重试')));
    }
  }

  void _openActiveTraining() {
    final active = _activeTrainingSession;
    final repository = _localTrainingRepository();
    if (active == null || repository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveTrainingPage(
          initialSession: active,
          engine: TrainingSessionEngine(repository: repository),
          repository: repository,
          catalog: exerciseCatalog,
          completedSessions: allTrainingSessions,
          coachMemories: _activeAiMemories(),
          onSessionChanged: (session) {
            if (mounted) setState(() => _activeTrainingSession = session);
          },
          onFinished: (session) async {
            final index = allTrainingSessions.indexWhere(
              (existing) => existing.id == session.id,
            );
            if (mounted) {
              setState(() {
                if (index == -1) {
                  allTrainingSessions.add(session);
                } else {
                  allTrainingSessions[index] = session;
                }
                _activeTrainingSession = null;
              });
            }
            await _saveData();
          },
        ),
      ),
    );
  }

  void _showTrainingHistorySheet() {
    final sessions = [...allTrainingSessions]
      ..sort((left, right) => right.date.compareTo(left.date));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.65,
          child: sessions.isEmpty
              ? const Center(child: Text('暂无训练记录'))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final session = sessions[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(session.name),
                      subtitle: Text(
                        '${session.date} · ${session.exercises.length} 个动作',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showTrainingSessionDetails(session);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showTrainingSessionDetails(TrainingSession session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: _buildTrainingSessionCard(session),
        ),
      ),
    );
  }

  Widget _buildTrainingSessionCard(TrainingSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 头部：名称 + 更多操作(修改/删除)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                session.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: GoatApp.marsGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "容量: ${session.sessionVolume.toInt()} kg",
                      style: const TextStyle(
                        color: GoatApp.marsGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  // 🌟 新增：训练课管理按钮
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onSelected: (val) {
                      if (val == 'edit')
                        _showRenameTrainingSessionSheet(session);
                      if (val == 'delete') {
                        setState(() => allTrainingSessions.remove(session));
                        _saveData();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text("重命名")),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          "删除训练",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF0F0F0)),
          TrainingRestSummary(session: session),
          const SizedBox(height: 10),

          // 2. 核心列表：逐行展示组，相同动作名称合并
          ...session.exercises.expand((ex) {
            return ex.sets.asMap().entries.map((entry) {
              int setIndex = entry.key;
              SetRecord set = entry.value;
              bool isFirstSet = setIndex == 0; // 是否是该动作的第一组

              return Slidable(
                // 🌟 新增：左滑删除动作组
                key: ValueKey(set.hashCode),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) {
                        setState(() => ex.sets.removeAt(setIndex));
                        _saveData();
                      },
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: '删除',
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => _showSetEditorSheet(
                    session,
                    ex.exerciseName,
                    ex.bodyPart,
                    existingSet: set,
                    setIndex: setIndex,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        // 动作名称：仅第一行显示
                        SizedBox(
                          width: 90,
                          child: isFirstSet
                              ? Text(
                                  ex.exerciseName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                )
                              : Container(),
                        ),
                        Text(
                          "第 ${setIndex + 1} 组",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
                        ),
                        const Spacer(),

                        // 核心数据与 1RM 预估
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "${set.weight}kg × ${set.reps}次",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (set.type != "正常") ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: set.type == "突破"
                                          ? Colors.orange
                                          : Colors.blueAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      set.type,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // 🌟 新增：突破组自动应用 Epley 公式预估 1RM
                            if (set.type == "突破" &&
                                set.weight > 0 &&
                                set.reps > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  "👑 1RM预估: ${(set.weight * (1 + 0.0333 * set.reps)).toStringAsFixed(1)}kg",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // 🌟 新增：启动组间休息倒计时的按钮
                        InkWell(
                          onTap: () => _startRestTimer(set.restSeconds),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: GoatApp.marsGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: GoatApp.marsGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            });
          }).toList(),

          const SizedBox(height: 12),
          // 添加动作按钮 (保持不变)
          InkWell(
            onTap: () => _showHybridExerciseSheet(session),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  "+ 添加训练动作",
                  style: TextStyle(
                    color: GoatApp.marsGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameTrainingSessionSheet(TrainingSession existingSession) {
    final TextEditingController nameController = TextEditingController(
      text: existingSession.name,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (dialogContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 40,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "重命名训练",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "输入训练名称",
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isEmpty) return;
                    setState(() {
                      existingSession.name = nameController.text;
                    });
                    Navigator.pop(dialogContext);
                    _saveData(); // 保存到本地/云端
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GoatApp.marsGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    "保存",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHybridExerciseSheet(TrainingSession session) {
    String selectedBodyPart = exerciseBodyParts.first;
    String selectedEquipment = '全部';
    String searchQuery = '';
    const equipmentOptions = ['全部', '徒手', '自由重量', '器械', '绳索', '壶铃'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredExercises = exerciseCatalog.where((exercise) {
              final matchesBodyPart = exercise.bodyPart == selectedBodyPart;
              final matchesEquipment =
                  selectedEquipment == '全部' ||
                  exercise.equipment == selectedEquipment;
              final matchesQuery =
                  searchQuery.isEmpty ||
                  exercise.name.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  exercise.equipment.contains(searchQuery);
              return matchesBodyPart && matchesEquipment && matchesQuery;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '添加动作',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${exerciseCatalog.length} 个动作',
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) =>
                        setModalState(() => searchQuery = value.trim()),
                    decoration: InputDecoration(
                      hintText: '搜索动作或器械',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF4F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: exerciseBodyParts.map((part) {
                        bool isSelected = selectedBodyPart == part;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedBodyPart = part),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.black87
                                  : const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              part,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black54,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: equipmentOptions.map((equipment) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(equipment),
                            selected: selectedEquipment == equipment,
                            selectedColor: GoatApp.marsGreen.withOpacity(0.12),
                            labelStyle: TextStyle(
                              color: selectedEquipment == equipment
                                  ? GoatApp.marsGreen
                                  : Colors.black54,
                              fontSize: 12,
                              fontWeight: selectedEquipment == equipment
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) => setModalState(
                              () => selectedEquipment = equipment,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: filteredExercises.isEmpty
                        ? const Center(
                            child: Text(
                              '没有匹配的动作',
                              style: TextStyle(color: Colors.black38),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredExercises.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final exercise = filteredExercises[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  exercise.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  exercise.equipment,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.add_circle_outline,
                                  color: GoatApp.marsGreen,
                                ),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _showSetEditorSheet(
                                    session,
                                    exercise.name,
                                    exercise.bodyPart,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // 新增：步骤2 - 动作数据录入面板 (重量/次数/分组)
  // ============================================================================
  void _showSetEditorSheet(
    TrainingSession session,
    String exName,
    String bodyPart, {
    SetRecord? existingSet,
    int? setIndex,
  }) {
    String inputWeight = existingSet?.weight.toString() ?? "";
    String inputReps = existingSet?.reps.toString() ?? "";
    String inputSets = "1";
    String selectedType = existingSet?.type ?? "正常";
    String inputRest = existingSet?.restSeconds.toString() ?? "90";
    String inputDuration = existingSet?.durationSec.toString() ?? "45";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existingSet == null ? "记录 $exName" : "修改第 ${setIndex! + 1} 组",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 难度选择 (复用之前的 UI)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ["🔥 热身", "⚡ 正常", "👑 突破"].map((t) {
                  bool isS = selectedType == t.split(" ")[1];
                  return GestureDetector(
                    onTap: () =>
                        setModalState(() => selectedType = t.split(" ")[1]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isS
                            ? GoatApp.marsGreen
                            : const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: isS ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "重量",
                      inputWeight,
                      (v) => inputWeight = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput("次数", inputReps, (v) => inputReps = v),
                  ),
                  if (existingSet == null) const SizedBox(width: 10),
                  if (existingSet == null)
                    Expanded(
                      child: _buildInput("组数", inputSets, (v) => inputSets = v),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      "单组耗时(秒)",
                      inputDuration,
                      (v) => inputDuration = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInput(
                      "组间休息(秒)",
                      inputRest,
                      (v) => inputRest = v,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  // 如果是编辑模式，增加一个“复制并添加”按钮
                  if (existingSet != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            final newSet = SetRecord(
                              weight: double.tryParse(inputWeight) ?? 0,
                              reps: int.tryParse(inputReps) ?? 0,
                              type: selectedType,
                            );
                            session.exercises
                                .firstWhere((e) => e.exerciseName == exName)
                                .sets
                                .add(newSet);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("复制此组"),
                      ),
                    ),
                  if (existingSet != null) const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GoatApp.marsGreen,
                      ),
                      onPressed: () {
                        setState(() {
                          double w = double.tryParse(inputWeight) ?? 0;
                          int r = int.tryParse(inputReps) ?? 0;
                          if (existingSet != null) {
                            existingSet.weight = w;
                            existingSet.reps = r;
                            existingSet.type = selectedType;
                            existingSet.restSeconds =
                                int.tryParse(inputRest) ?? 90;
                            existingSet.durationSec =
                                int.tryParse(inputDuration) ?? 45;
                          } else {
                            var ex = session.exercises.firstWhere(
                              (e) => e.exerciseName == exName,
                              orElse: () {
                                var newEx = TrainingExercise(
                                  exerciseName: exName,
                                  bodyPart: bodyPart,
                                  sets: [],
                                );
                                session.exercises.add(newEx);
                                return newEx;
                              },
                            );
                            for (
                              int i = 0;
                              i < (int.tryParse(inputSets) ?? 1);
                              i++
                            )
                              ex.sets.add(
                                SetRecord(
                                  weight: w,
                                  reps: r,
                                  type: selectedType,
                                  restSeconds: int.tryParse(inputRest) ?? 90,
                                  durationSec:
                                      int.tryParse(inputDuration) ?? 45,
                                ),
                              );
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        existingSet == null ? "完成添加" : "保存修改",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 辅助方法：快速构建输入框
  Widget _buildInput(String label, String initial, Function(String) onChange) {
    return TextField(
      controller: TextEditingController(text: initial)
        ..selection = TextSelection.collapsed(offset: initial.length),
      keyboardType: TextInputType.number,
      onChanged: onChange,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF4F5F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ============================================================================
  // 账号交互弹窗逻辑
  // ============================================================================
  void _showLoginDialog() {
    // 🌟 在状态构建器外层声明所有交互变量
    bool isPhoneMode = true; // true = 手机号验证码模式, false = 电子邮箱模式
    bool isEmailRegister = false; // 邮箱模式下：true = 注册新账号, false = 账号登录

    String phone = '';
    String smsCode = '';
    String email = '';
    String password = '';
    bool isProcessing = false;

    int countdown = 0;
    Timer? timer; // 用于手机验证码 60 秒倒计时

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),

            // 🌟 核心改进 1：顶层采用双选项卡切换，彻底解决“手机登录写着邮箱”的文案冲突
            title: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setDialogState(() => isPhoneMode = true),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isPhoneMode
                                ? GoatApp.marsGreen
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        '手机验证码',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isPhoneMode
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isPhoneMode ? GoatApp.marsGreen : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setDialogState(() => isPhoneMode = false),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !isPhoneMode
                                ? GoatApp.marsGreen
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        '邮箱密码',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: !isPhoneMode
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: !isPhoneMode ? GoatApp.marsGreen : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📱 手机验证码布局
                  if (isPhoneMode) ...[
                    TextField(
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: '手机号',
                        hintText: '请输入11位手机号',
                        prefixText: '+86 ',
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: GoatApp.marsGreen),
                        ),
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                      onChanged: (v) => phone = v.trim(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '验证码',
                              hintText: '6位验证码',
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: GoatApp.marsGreen,
                                ),
                              ),
                              labelStyle: TextStyle(color: Colors.grey),
                            ),
                            onChanged: (v) => smsCode = v.trim(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 验证码倒计时按钮
                        TextButton(
                          onPressed: (countdown > 0 || isProcessing)
                              ? null
                              : () async {
                                  if (phone.isEmpty || phone.length < 11) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('请输入正确的手机号'),
                                      ),
                                    );
                                    return;
                                  }
                                  setDialogState(() => isProcessing = true);
                                  try {
                                    // 调用 Supabase 手机 OTP 接口
                                    await supabase.auth.signInWithOtp(
                                      phone: '+86$phone',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('验证码已发送')),
                                    );
                                    setDialogState(() {
                                      countdown = 60;
                                      isProcessing = false;
                                    });
                                    // 启动倒计时，并优雅处理弹窗关闭后的异常
                                    timer?.cancel();
                                    timer = Timer.periodic(
                                      const Duration(seconds: 1),
                                      (t) {
                                        try {
                                          setDialogState(() {
                                            if (countdown > 0) {
                                              countdown--;
                                            } else {
                                              t.cancel();
                                            }
                                          });
                                        } catch (_) {
                                          t.cancel(); // 捕获弹窗已被关闭时的异常，安全释放定时器
                                        }
                                      },
                                    );
                                  } catch (e) {
                                    setDialogState(() => isProcessing = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('发送失败: $e')),
                                    );
                                  }
                                },
                          child: Text(
                            countdown > 0 ? '$countdown 秒' : '获取验证码',
                            style: const TextStyle(color: GoatApp.marsGreen),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '💡 提示：未注册的手机号验证后将自动创建账号。',
                      style: TextStyle(fontSize: 12, color: Colors.black38),
                    ),
                  ]
                  // 📧 邮箱密码布局
                  else ...[
                    // 🌟 核心改进 2：在邮箱内提供极醒目的 ChoiceChip 状态切片，彻底消除登录/注册的混淆
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('账号登录'),
                          selected: !isEmailRegister,
                          selectedColor: GoatApp.marsGreen.withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: !isEmailRegister
                                ? GoatApp.marsGreen
                                : Colors.grey,
                            fontWeight: !isEmailRegister
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) =>
                              setDialogState(() => isEmailRegister = false),
                        ),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('注册新账号'),
                          selected: isEmailRegister,
                          selectedColor: GoatApp.marsGreen.withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: isEmailRegister
                                ? GoatApp.marsGreen
                                : Colors.grey,
                            fontWeight: isEmailRegister
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) =>
                              setDialogState(() => isEmailRegister = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        hintText: 'xxx@qq.com',
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: GoatApp.marsGreen),
                        ),
                      ),
                      onChanged: (v) => email = v.trim(),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '密码 (最少6位)',
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: GoatApp.marsGreen),
                        ),
                      ),
                      obscureText: true,
                      onChanged: (v) => password = v.trim(),
                    ),
                    // 只有在登录状态下才暴露“忘记密码”
                    if (!isEmailRegister) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          timer?.cancel();
                          Navigator.pop(context);
                          _showForgotPasswordDialog();
                        },
                        child: const Text(
                          '忘记密码？',
                          style: TextStyle(
                            color: GoatApp.marsGreen,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            actions: [
              // 取消按钮
              TextButton(
                onPressed: isProcessing
                    ? null
                    : () {
                        timer?.cancel();
                        Navigator.pop(context);
                      },
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),

              // 🌟 核心改进 3：右下角变为动态单一主动作按钮，根据当前选中的状态自动执行对应的逻辑
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GoatApp.marsGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        // ---- A. 手机号通道验证 ----
                        if (isPhoneMode) {
                          if (phone.isEmpty || smsCode.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请填写手机号和验证码')),
                            );
                            return;
                          }
                          setDialogState(() => isProcessing = true);
                          try {
                            final res = await supabase.auth.verifyOTP(
                              type: OtpType.sms,
                              token: smsCode,
                              phone: '+86$phone',
                            );
                            if (res.session != null) {
                              timer?.cancel();
                              if (context.mounted)
                                Navigator.pop(context); // 安全关闭弹窗
                              if (mounted) {
                                setState(() {
                                  _isAppLoading = true;
                                });
                                await _initUserAndData(); // 完美对接你原有的同步函数
                              }
                            }
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('验证失败：验证码错误或已过期')),
                              );
                          } finally {
                            setDialogState(() => isProcessing = false);
                          }
                        }
                        // ---- B. 邮箱通道验证 ----
                        else {
                          if (email.isEmpty || password.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('邮箱不能为空，密码至少6位')),
                            );
                            return;
                          }
                          setDialogState(() => isProcessing = true);
                          try {
                            if (isEmailRegister) {
                              // 邮箱注册分支
                              await supabase.auth.signUp(
                                email: email,
                                password: password,
                              );
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('注册成功！已为您自动切换到登录'),
                                  ),
                                );
                              setDialogState(
                                () => isEmailRegister = false,
                              ); // 注册成功后贴心自动切回登录，让用户直接输入登录
                            } else {
                              // 邮箱登录分支
                              await supabase.auth.signInWithPassword(
                                email: email,
                                password: password,
                              );
                              timer?.cancel();
                              if (context.mounted) Navigator.pop(context);
                              if (mounted) {
                                setState(() {
                                  _isAppLoading = true;
                                });
                                await _initUserAndData();
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEmailRegister
                                        ? '注册失败: $e'
                                        : '登录失败：账号或密码错误',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => isProcessing = false);
                          }
                        }
                      },
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isPhoneMode
                            ? '进入 GOAT'
                            : (isEmailRegister ? '立即注册' : '登录'),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editUserName() async {
    final user = supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return;

    String currentName = user.userMetadata?['display_name'] ?? 'G O A T 玩家';
    String newName = currentName;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '修改昵称',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          onChanged: (val) => newName = val,
          decoration: const InputDecoration(
            hintText: '输入新昵称',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: GoatApp.marsGreen),
            ),
          ),
          cursorColor: GoatApp.marsGreen,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await supabase.auth.updateUser(
                  UserAttributes(data: {'display_name': newName}),
                );
                if (mounted) setState(() {});
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('昵称修改成功！')));
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('修改失败: $e')));
              }
            },
            child: const Text(
              '保存',
              style: TextStyle(
                color: GoatApp.marsGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final namespaceBeforeSignOut = _activeNamespace;
    await _saveLocalPreferencesOnly();
    await supabase.auth.signOut();
    if (_activeNamespace == namespaceBeforeSignOut) {
      _activeUserId = null;
      _activeNamespace = _storage?.namespaceForUser(null) ?? 'guest';
      _applySnapshot(_storage?.load(_activeNamespace) ?? AppSnapshot.empty());
    }
  }

  Future<void> _deleteAccount() => _showDataPrivacyPage();

  // 🌟 新增功能：OTP 验证码找回密码对话框
  void _showForgotPasswordDialog() {
    String resetEmail = '';
    String otpCode = '';
    String newPassword = '';
    int step = 1;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              '找回密码',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 1) ...[
                  const Text(
                    '请输入您注册时的邮箱，我们将向您发送验证码。',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '注册邮箱',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: GoatApp.marsGreen),
                      ),
                    ),
                    onChanged: (v) => resetEmail = v.trim(),
                  ),
                ] else ...[
                  Text(
                    '已向 $resetEmail 发送验证码，请查收邮件。',
                    style: const TextStyle(
                      fontSize: 13,
                      color: GoatApp.marsGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    // 🌟 修复：去掉了“6位数字”的提示，并且允许输入字母（如果 Supabase 发的是 Token）
                    decoration: const InputDecoration(
                      labelText: '邮箱验证码',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: GoatApp.marsGreen),
                      ),
                    ),
                    keyboardType: TextInputType.visiblePassword,
                    onChanged: (v) => otpCode = v.trim(),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '设置新密码 (最少6位)',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: GoatApp.marsGreen),
                      ),
                    ),
                    obscureText: true,
                    onChanged: (v) => newPassword = v.trim(),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GoatApp.marsGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDialogState(() => isProcessing = true);
                        try {
                          if (step == 1) {
                            if (resetEmail.isEmpty || !resetEmail.contains('@'))
                              throw Exception('请输入有效的邮箱');
                            await supabase.auth.resetPasswordForEmail(
                              resetEmail,
                            );
                            setDialogState(() => step = 2);
                          } else {
                            // 🌟 修复：移除了 otpCode.length != 6 的死板限制
                            if (otpCode.isEmpty) throw Exception('验证码不能为空');
                            if (newPassword.length < 6)
                              throw Exception('新密码不能少于6位');

                            await supabase.auth.verifyOTP(
                              type: OtpType.recovery,
                              email: resetEmail,
                              token: otpCode,
                            );
                            await supabase.auth.updateUser(
                              UserAttributes(password: newPassword),
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('密码重置成功，请重新登录！')),
                              );
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceAll('Exception: ', ''),
                              ),
                            ),
                          );
                        } finally {
                          setDialogState(() => isProcessing = false);
                        }
                      },
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(step == 1 ? '发送验证码' : '确认重置'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================================
  // 4. 页面级 UI 构建 (PAGES)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    // 1. 加载状态：保持原样
    if (_isAppLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'G O A T',
                style: TextStyle(
                  fontWeight: FontWeight.w200,
                  letterSpacing: 8.0,
                  fontSize: 36,
                  color: GoatApp.marsGreen,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: GoatApp.marsGreen,
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              const Text(
                '正在同步健康档案...',
                style: TextStyle(
                  color: Colors.black38,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. 正常状态：在 IndexedStack 外层包裹 Stack 以实现倒计时悬浮
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Stack(
        children: [
          // 底层：正常的页面内容
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildDashboardPage(),
              _buildCalendarPage(),
              _buildTrainingPage(),
              _buildPlanPage(),
              _buildProfileAccountCenter(),
            ],
          ),

          // 顶层：🌟 组间休息倒计时悬浮窗
          if (_restTimeRemaining > 0)
            Positioned(
              // 适配刘海屏，放在屏幕右上角
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  // 点击圆环可以提前结束休息
                  _restTimer?.cancel();
                  setState(() => _restTimeRemaining = 0);
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 进度条背景
                      CircularProgressIndicator(
                        value: _restTimeRemaining / _restTimeTotal,
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          GoatApp.marsGreen,
                        ),
                        strokeWidth: 4,
                      ),
                      // 中间数字
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_restTimeRemaining',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: GoatApp.marsGreen,
                                height: 1.2,
                              ),
                            ),
                            const Text(
                              'SEC',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.black26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: GoatApp.marsGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '主页'),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: '历史',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            label: '训练',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.tune_rounded), label: '计划'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardPage() {
    final stats = _getDailyStats(viewDateStr);
    final consumed = allConsumedItems
        .where((i) => i.date == viewDateStr)
        .toList();
    final currentDate = DateUtils.dateOnly(
      DateTime.tryParse(viewDateStr) ?? DateTime.now(),
    );
    final previousWeight =
        dailyWeight[_dateKey(currentDate.subtract(const Duration(days: 1)))];
    final weeklyNutrition = const WeeklyNutritionReviewCalculator().calculate(
      records: allConsumedItems,
      weightRecords: _weightRecords(),
      anchorDate: currentDate,
    );
    final nutritionCoach = const AiCoachScenarioService().nutrition(
      review: weeklyNutrition,
      calorieTarget: targetKcal,
      memories: _activeAiMemories(),
      trainingGoal: _profileMemory(AiProfileCategory.trainingGoal),
      nutritionPreference: _profileMemory(
        AiProfileCategory.nutritionPreference,
      ),
    );
    return HomePage(
      businessDate: viewDateStr,
      isToday: isToday,
      stats: stats,
      targetKcal: targetKcal,
      targetProtein: targetP,
      targetCarbs: targetC,
      targetFat: targetF,
      waterMl: _waterTotalForDate(viewDateStr),
      weight: dailyWeight[viewDateStr] ?? currentWeight,
      previousWeight: previousWeight,
      weightTrend: _weightTrendFor(currentDate),
      consumed: consumed,
      coachExplanation: nutritionCoach,
      aiContent: _currentAiTip,
      isAiLoading: _isAiTipLoading,
      showAiCard: aiDismissedDate != viewDateStr,
      onEditTarget: _showTargetSettingsDialog,
      onRequestAiAdvice: _fetchDailyAiTip,
      onDismissAi: () {
        setState(() => aiDismissedDate = viewDateStr);
        _saveLocalPreferencesOnly();
      },
      onQuickAddWater: _quickAddHomeWater,
      onOpenWater: _showWaterTrackingPage,
      onOpenWeight: _showWeightPickerForDate,
      onOpenMeal: (mealType) => _showMealDetailPopup(
        mealType,
        mealType,
        _dashboardMealRecords(mealType, consumed),
      ),
      onAddMeal: _showNutritionQuickAdd,
      onVoiceMeal: (mealType) {
        unawaited(
          showVoiceEntrySheet(
            context: context,
            mealType: mealType,
            speechService: _speechService,
            nutritionService: _nutritionAiService,
            repository: this,
          ),
        );
      },
      onOpenTraining: () => setState(() => _currentIndex = 2),
      onAddExercise: _showExerciseAddDialog,
    );
  }

  List<ConsumedRecord> _dashboardMealRecords(
    String mealType,
    Iterable<ConsumedRecord> consumed,
  ) => consumed
      .where((record) {
        if (mealType == '加餐') {
          return record.mealType != '早餐' &&
              record.mealType != '午餐' &&
              record.mealType != '晚餐';
        }
        return record.mealType == mealType;
      })
      .toList(growable: false);

  Future<void> _quickAddHomeWater() async {
    final now = DateTime.now();
    await addWaterRecord(
      WaterIntakeRecord(
        id: 'water_${now.microsecondsSinceEpoch}',
        date: viewDateStr,
        recordedAt: now,
        amountMl: 250,
      ),
    );
  }

  // --- 历史页面 ---
  // 这个函数专门提取自你原本的 _buildMacronutrientsCard，只保留核心 UI
  Widget _buildMacronutrientsContent(DailyMacroStats stats) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '今日摄入概览',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${stats.kcalIn.toInt()} / ${targetKcal.toInt()} kcal',
              style: TextStyle(
                color: GoatApp.marsGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _semiCircleWithLabel(
              '蛋白质',
              stats.p,
              targetP,
              const Color(0xFF4D6BFE),
            ),
            _semiCircleWithLabel(
              '碳水',
              stats.c,
              targetC,
              const Color(0xFFF6AD55),
            ),
            _semiCircleWithLabel(
              '脂肪',
              stats.f,
              targetF,
              const Color(0xFFF56565),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarPage() {
    final stats = _getDailyStats(viewDateStr);
    final consumed = allConsumedItems
        .where((i) => i.date == viewDateStr)
        .toList();
    final exercises = allExerciseItems
        .where((e) => e.date == viewDateStr)
        .toList();
    final statisticsDates = _statisticsDates();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F7),
        elevation: 0,
        title: const Text(
          '历 史 记 录',
          style: TextStyle(
            fontWeight: FontWeight.w200,
            letterSpacing: 4.0,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // 1. 打卡日历
          _buildCustomCalendar(),
          const SizedBox(height: 16),

          // 🌟 2. 融合后的“三环+明细”大卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 上半部分：三环图内容 (复用你原有的 UI 逻辑，但去掉了外层 Container)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildMacronutrientsContent(
                      stats,
                    ), // 注意：这里我改用了一个纯内容函数
                  ),

                  const Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: Color(0xFFF0F0F0),
                  ),

                  // 下半部分：折叠明细
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                      initiallyExpanded: _isHistoryExpanded,
                      onExpansionChanged: (val) =>
                          setState(() => _isHistoryExpanded = val),
                      title: Text(
                        _isHistoryExpanded
                            ? "收起今日明细"
                            : "展开记录明细 (${consumed.length + exercises.length} 条)",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 20,
                          ),
                          child: Column(
                            children: [
                              _buildConciseGroupCard(
                                '正餐记录',
                                Icons.restaurant_menu,
                                [
                                  _buildSubGroup(
                                    '早餐',
                                    consumed
                                        .where((e) => e.mealType == '早餐')
                                        .toList(),
                                    () => _showFoodPicker(context, '早餐'),
                                  ),
                                  _buildSubGroup(
                                    '午餐',
                                    consumed
                                        .where((e) => e.mealType == '午餐')
                                        .toList(),
                                    () => _showFoodPicker(context, '午餐'),
                                  ),
                                  _buildSubGroup(
                                    '晚餐',
                                    consumed
                                        .where((e) => e.mealType == '晚餐')
                                        .toList(),
                                    () => _showFoodPicker(context, '晚餐'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildConciseGroupCard(
                                '额外补充',
                                Icons.add_moderator_outlined,
                                [
                                  _buildSubGroup(
                                    '补剂',
                                    consumed
                                        .where((e) => e.mealType == '补剂')
                                        .toList(),
                                    () => _showFoodPicker(context, '加餐'),
                                  ),
                                  _buildSubGroup(
                                    '日常补充',
                                    consumed
                                        .where((e) => e.mealType == '日常补充')
                                        .toList(),
                                    () => _showFoodPicker(context, '加餐'),
                                  ),
                                ],
                              ),
                              if (exercises.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildExerciseSection(exercises, stats.burn),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildDailyTrainingSummary(viewDateStr),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          _buildStatisticsPeriodControl(),
          const SizedBox(height: 16),
          _buildPeriodOverviewCard(statisticsDates),
          const SizedBox(height: 16),
          _buildRadarChartContainer(stats),
          const SizedBox(height: 16),
          _buildMacroStackedBarChartContainer(statisticsDates),
          const SizedBox(height: 16),
          _buildDivergingBarChartContainer(statisticsDates),
          const SizedBox(height: 16),
          _buildWeightTrendChartContainer(statisticsDates),
          const SizedBox(height: 16),
          _buildTrainingVolumeChartContainer(statisticsDates),
        ],
      ),
    );
  }

  Widget _buildCustomCalendar() {
    DateTime firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    int daysInMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    ).day;
    int firstWeekday = firstDay.weekday;

    List<Widget> dayWidgets = [];
    List<String> weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    for (var w in weekDays) {
      dayWidgets.add(
        Center(
          child: Text(
            w,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    for (int i = 1; i < firstWeekday; i++) dayWidgets.add(const SizedBox());

    Set<String> activeDates = {};
    activeDates.addAll(allConsumedItems.map((e) => e.date));
    activeDates.addAll(allExerciseItems.map((e) => e.date));
    activeDates.addAll(waterIntakeRecords.map((e) => e.date));

    Set<String> trainingDates = {};
    trainingDates.addAll(allTrainingSessions.map((e) => e.date));

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime dayDate = DateTime(_calendarMonth.year, _calendarMonth.month, i);
      String dayStr = dayDate.toString().substring(0, 10);
      bool isSelected = dayStr == viewDateStr;
      bool hasRecord = activeDates.contains(dayStr);
      bool hasTraining = trainingDates.contains(dayStr);

      dayWidgets.add(
        HistoryCalendarDay(
          day: i,
          dateKey: dayStr,
          isSelected: isSelected,
          hasRecord: hasRecord,
          hasTraining: hasTraining,
          onTap: () => setState(() => viewDateStr = dayStr),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(top: 10, bottom: 20, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black54),
                onPressed: () => setState(
                  () => _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month - 1,
                    1,
                  ),
                ),
              ),
              Text(
                "${_calendarMonth.year}年 ${_calendarMonth.month}月",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.black54),
                onPressed: () => setState(
                  () => _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month + 1,
                    1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: dayWidgets,
          ),
        ],
      ),
    );
  }

  String get _statisticsPeriodLabel {
    return _statisticsPeriod == StatisticsPeriod.week ? '近一周' : '近一月';
  }

  Widget _buildStatisticsPeriodControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SegmentedButton<StatisticsPeriod>(
        segments: const [
          ButtonSegment(
            value: StatisticsPeriod.week,
            icon: Icon(Icons.date_range_outlined),
            label: Text('近一周'),
          ),
          ButtonSegment(
            value: StatisticsPeriod.month,
            icon: Icon(Icons.calendar_month_outlined),
            label: Text('近一月'),
          ),
        ],
        selected: {_statisticsPeriod},
        onSelectionChanged: (selection) =>
            setState(() => _statisticsPeriod = selection.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : GoatApp.marsGreen,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? GoatApp.marsGreen
                : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodOverviewCard(List<DateTime> dates) {
    final periodStats = _getPeriodStats(dates);
    final dateKeys = dates.map(_dateKey).toSet();
    final activeDays = dateKeys.where((date) {
      return allConsumedItems.any((item) => item.date == date) ||
          allExerciseItems.any((item) => item.date == date) ||
          waterIntakeRecords.any((item) => item.date == date) ||
          allTrainingSessions.any((session) => session.date == date);
    }).length;
    final trainingVolume = allTrainingSessions
        .where((session) => dateKeys.contains(session.date))
        .fold(0.0, (sum, session) => sum + session.sessionVolume);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodStat(
              '记录天数',
              '$activeDays/${dates.length}',
              Icons.event_available_outlined,
              GoatApp.marsGreen,
            ),
          ),
          Expanded(
            child: _buildPeriodStat(
              '日均摄入',
              '${(periodStats.kcalIn / dates.length).round()} kcal',
              Icons.local_fire_department_outlined,
              Colors.deepOrangeAccent,
            ),
          ),
          Expanded(
            child: _buildPeriodStat(
              '训练容量',
              '${trainingVolume.round()} kg',
              Icons.fitness_center_outlined,
              Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Colors.black38),
        ),
      ],
    );
  }

  // --- 辅助：雷达图外壳 ---
  Widget _buildRadarChartContainer(DailyMacroStats stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "单日综合评分雷达",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: RadarScorePainter(
                  stats,
                  targetKcal,
                  targetP,
                  targetC,
                  targetF,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 辅助：堆叠柱状图外壳 ---
  Widget _buildMacroStackedBarChartContainer(List<DateTime> dates) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_statisticsPeriodLabel 营养构成 (P/C/F)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: MacroStackedBarPainter(allConsumedItems, dates),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend(const Color(0xFF4D6BFE), "蛋白质"),
              const SizedBox(width: 12),
              _buildChartLegend(const Color(0xFFF6AD55), "碳水"),
              const SizedBox(width: 12),
              _buildChartLegend(const Color(0xFFF56565), "脂肪"),
            ],
          ),
        ],
      ),
    );
  }

  // --- 辅助：双向条形图外壳 ---
  Widget _buildDivergingBarChartContainer(List<DateTime> dates) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_statisticsPeriodLabel 热量收支 (摄入 vs 运动)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: CalorieDivergingBarPainter(
                  allConsumedItems,
                  allExerciseItems,
                  dates,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend(GoatApp.marsGreen, "饮食摄入"),
              const SizedBox(width: 12),
              _buildChartLegend(Colors.orangeAccent, "运动消耗"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTrendChartContainer(List<DateTime> dates) {
    final anchor = DateUtils.dateOnly(
      DateTime.tryParse(viewDateStr) ?? DateTime.now(),
    );
    final trend = _weightTrendFor(anchor);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_statisticsPeriodLabel 体重趋势',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 14),
          WeightTrendSummary(trend: trend),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: WeightTrendPainter(dailyWeight, dates),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildChartLegend(Colors.orangeAccent, '体重记录'),
        ],
      ),
    );
  }

  Widget _buildTrainingVolumeChartContainer(List<DateTime> dates) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_statisticsPeriodLabel 训练容量',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: TrainingVolumePainter(allTrainingSessions, dates),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildChartLegend(Colors.indigo, '总重量 x 次数'),
        ],
      ),
    );
  }

  // --- 辅助：图例小组件 ---
  Widget _buildChartLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  // --- 计划页面 ---
  Widget _buildPlanPage() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F7),
        elevation: 0,
        title: const GoatPageHeader(title: '个 人 定 制 计 划'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF006363),
                  Color(0xFF007777),
                  Color(0xFF008C8C),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF008C8C).withValues(alpha: 0.26),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT PLAN / 当前配置预览',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _planStatItem('目标热量', targetKcal.toInt(), 'KCAL'),
                    Container(width: 1, height: 30, color: Colors.white24),
                    _planStatItem('蛋白质', targetP.toInt(), 'G'),
                    _planStatItem('碳水', targetC.toInt(), 'G'),
                    _planStatItem('脂肪', targetF.toInt(), 'G'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildConciseGroupCard('计划模式', Icons.settings_suggest_outlined, [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '开启周循环模式',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                CupertinoSwitch(
                  activeColor: GoatApp.marsGreen,
                  value: isCyclingMode,
                  onChanged: (val) => setState(() => isCyclingMode = val),
                ),
              ],
            ),
            if (isCyclingMode) _buildWeekSelector(),
          ]),
          const SizedBox(height: 12),
          _buildConciseGroupCard(
            '饮食目标设置 ${isCyclingMode ? "(周$selectedDay)" : ""}',
            Icons.restaurant_outlined,
            [
              _buildTargetSlider(
                '热量 (kcal)',
                targetKcal,
                1200,
                3500,
                (v) => setState(() => targetKcal = v),
              ),
              _buildTargetSlider(
                '蛋白质 (g)',
                targetP,
                40,
                250,
                (v) => setState(() => targetP = v),
              ),
              _buildTargetSlider(
                '碳水 (g)',
                targetC,
                50,
                400,
                (v) => setState(() => targetC = v),
              ),
              _buildTargetSlider(
                '脂肪 (g)',
                targetF,
                20,
                150,
                (v) => setState(() => targetF = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildConciseGroupCard('运动消耗计划', Icons.fitness_center_rounded, [
            _buildTargetSlider('每日运动目标 (kcal)', 500, 0, 1500, (v) {}),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '设定后将作为每日运动进度条的达成标准',
                style: TextStyle(fontSize: 11, color: Colors.black26),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _saveData();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('计划已保存')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GoatApp.marsGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: const Text(
              '保 存 全 局 计 划',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileAccountCenter() {
    final identity = _profileIdentity();
    return ProfilePage(
      identity: identity,
      basicData: ProfileBasicData(
        gender: gender,
        birthYear: birthYear,
        birthMonth: birthMonth,
        birthDay: birthDay,
        heightCm: height,
        currentWeightKg: currentWeight,
      ),
      summaryLoader: _loadProfileSummary,
      onSaveBasic: _saveProfileBasic,
      onSaveProfileValue: _saveProfileValue,
      equipmentOptions:
          exerciseCatalog.map((item) => item.equipment).toSet().toList()
            ..sort(),
      onOpenTrainingHistory: _openTrainingHistoryFromProfile,
      onOpenWeeklyReview: _openWeeklyReviewFromProfile,
      onOpenWeightHistory: _showWeightHistoryPage,
      onManageTrainingPlans: _showTrainingTemplateManager,
      onOpenAiProfile: _showAiProfilePage,
      onOpenSuggestionHistory: _showSuggestionHistoryPage,
      onOpenKnowledgeExplanation: _showAiKnowledgeExplanationPage,
      onOpenAllRecords: _showRecordsHubPage,
      onOpenDataPrivacy: _showDataPrivacyPage,
      onOpenAbout: _showAboutGoatPage,
      onOpenLicenses: _showLicenses,
      onLogin: () async => _showLoginDialog(),
      onLogout: _signOut,
    );
  }

  ProfileIdentity _profileIdentity() {
    final user = supabase.auth.currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;
    return ProfileIdentity(
      isLoggedIn: isLoggedIn,
      displayName: isLoggedIn
          ? (user.userMetadata?['display_name'] as String? ?? '')
          : '',
      email: isLoggedIn ? (user.email ?? '') : '',
    );
  }

  Future<ProfileSummary> _loadProfileSummary() {
    final storage = _storage;
    final trainingRepository =
        _localTrainingRepository() ??
        InMemoryTrainingRepository(completedSessions: allTrainingSessions);
    final aiState = storage == null
        ? const AiCoachState()
        : AiCoachLocalRepository(
            preferences: storage.prefs,
            namespace: _activeNamespace,
          ).load();
    final templateCount = _localTrainingTemplateStore()?.load().length ?? 0;
    return const ProfileSummaryService().load(
      identity: _profileIdentity(),
      trainingRepository: trainingRepository,
      weightRecords: _weightRecords(),
      aiState: aiState,
      trainingTemplateCount: templateCount,
      anchorDate: DateTime.now(),
    );
  }

  Future<void> _saveProfileBasic(ProfileBasicUpdate update) async {
    final user = supabase.auth.currentUser;
    if (user != null &&
        !user.isAnonymous &&
        update.displayName !=
            (user.userMetadata?['display_name'] as String? ?? '')) {
      await supabase.auth.updateUser(
        UserAttributes(data: {'display_name': update.displayName}),
      );
    }
    if (!mounted) return;
    setState(() {
      gender = update.gender;
      birthYear = update.birthYear;
      height = update.heightCm;
    });
    await _saveData();
  }

  Future<void> _saveProfileValue(
    AiProfileCategory category,
    String? value,
  ) async {
    final storage = _storage;
    if (storage == null) throw StateError('本地数据尚未准备完成');
    await AiCoachLocalRepository(
      preferences: storage.prefs,
      namespace: _activeNamespace,
    ).setUserProfileValue(category: category, value: value);
  }

  Future<void> _openTrainingHistoryFromProfile() async {
    _showTrainingHistorySheet();
  }

  Future<void> _openWeeklyReviewFromProfile() async {
    _showWeeklyReviewPage();
  }

  Future<void> _showWeightHistoryPage() async {
    final records = _weightRecords();
    final trend = _weightTrendFor(DateTime.now());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeightHistoryPage(
          trend: trend,
          records: records,
          onAddWeight: () async => _showWeightPickerForDate(),
        ),
      ),
    );
  }

  Future<void> _showSuggestionHistoryPage() async {
    final storage = _storage;
    if (storage == null) return;
    final repository = AiCoachLocalRepository(
      preferences: storage.prefs,
      namespace: _activeNamespace,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SuggestionHistoryPage(stateLoader: repository.load),
      ),
    );
  }

  Future<void> _showAiKnowledgeExplanationPage() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AiKnowledgeExplanationPage()),
  );

  Future<void> _showRecordsHubPage() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RecordsHubPage(
        onOpenWeight: _showWeightHistoryPage,
        onOpenTraining: _openTrainingHistoryFromProfile,
        onOpenWeeklyReview: _openWeeklyReviewFromProfile,
        onOpenDiet: () async {
          Navigator.of(context).pop();
          if (mounted) setState(() => _currentIndex = 1);
        },
        onOpenWater: _showWaterTrackingPage,
      ),
    ),
  );

  Future<void> _showDataPrivacyPage() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DataPrivacyPage(
        isLoggedIn: _profileIdentity().isLoggedIn,
        onExportCloud: _exportCloudUserData,
        onExportLocal: _exportLocalUserData,
        onOpenAiProfile: _showAiProfilePage,
        onDeleteAccount: _deleteAccountWithConfirmation,
      ),
    ),
  );

  Future<String> _exportCloudUserData() {
    return UserDataExportService(
      isAuthenticated: () {
        final user = supabase.auth.currentUser;
        return user != null && !user.isAnonymous;
      },
      invokeExport: () async {
        final response = await supabase.functions.invoke(
          'export-user-data',
          body: const {},
        );
        return response.data;
      },
      deliver: deliverJsonFile,
    ).exportCloudData();
  }

  Future<String> _exportLocalUserData() async {
    final storage = _storage;
    if (storage == null) throw StateError('本地数据尚未准备完成');
    final aiState = AiCoachLocalRepository(
      preferences: storage.prefs,
      namespace: _activeNamespace,
    ).load();
    final templates = _localTrainingTemplateStore()?.load() ?? const [];
    final snapshot = storage.load(_activeNamespace) ?? _snapshotFromState();
    return LocalUserDataExportService(deliver: deliverJsonFile).export({
      'scope': _activeUserId == null ? 'local' : 'current-account',
      'appSnapshot': snapshot.toJson(),
      'trainingTemplates': templates.map((item) => item.toJson()).toList(),
      'aiCoach': aiState.toJson(),
    });
  }

  Future<void> _deleteAccountWithConfirmation(String confirmation) async {
    final storage = _storage;
    final userId = _activeUserId;
    if (storage == null) throw StateError('本地数据尚未准备完成');
    if (userId == null) throw StateError('需要先登录账号');
    await supabase.auth.reauthenticate();
    await AccountDeletionService(
      userId: userId,
      namespaceForUser: (id) => storage.namespaceForUser(id),
      invokeRemoteDelete: (phrase) async {
        await supabase.functions.invoke(
          'delete-account',
          body: {'confirmPhrase': phrase},
        );
      },
      clearLocalNamespace: (namespace) async {
        _activeUserId = null;
        _activeNamespace = storage.namespaceForUser(null);
        _applySnapshot(storage.load(_activeNamespace) ?? AppSnapshot.empty());
        await storage.clearNamespace(namespace);
        await AiCoachLocalRepository(
          preferences: storage.prefs,
          namespace: namespace,
        ).clear();
        await TrainingTemplateStore(
          preferences: storage.prefs,
          namespace: namespace,
        ).clear();
      },
      signOut: () => supabase.auth.signOut(),
    ).deleteCurrentAccount(confirmation: confirmation);
    if (mounted) {
      _rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('账号及当前本地空间已删除')),
      );
    }
  }

  Future<void> _showAboutGoatPage() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AboutGoatPage(
        onOpenPrivacy: _showDataPrivacyPage,
        onOpenLicenses: _showLicenses,
      ),
    ),
  );

  Future<void> _showLicenses() async {
    showLicensePage(
      context: context,
      applicationName: 'GOAT',
      applicationLegalese: '训练、饮食与身体趋势记录工具',
    );
  }

  // --- 旧个人中心保留为不可达代码，待主文件后续模块化时移除。 ---
  // ignore: unused_element
  Widget _buildProfilePage() {
    final user = supabase.auth.currentUser;
    final bool isLoggedIn = (user != null && !user.isAnonymous);
    final String email = isLoggedIn ? user.email! : '登录解锁云端多设备同步功能';
    final String displayName =
        user?.userMetadata?['display_name'] ?? 'G O A T 玩家';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '个 人 主 页',
              style: TextStyle(
                fontWeight: FontWeight.w200,
                letterSpacing: 4.0,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isLoggedIn
                        ? GoatApp.marsGreen.withOpacity(0.2)
                        : Colors.grey[200],
                    child: Text(
                      isLoggedIn
                          ? (displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'G')
                          : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isLoggedIn ? GoatApp.marsGreen : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isLoggedIn ? displayName : "未登录",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isLoggedIn) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _editUserName,
                                child: const Icon(
                                  Icons.edit_square,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLoggedIn)
                    TextButton(
                      onPressed: _showLoginDialog,
                      child: const Text(
                        '去登录',
                        style: TextStyle(
                          color: GoatApp.marsGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.assignment_ind_outlined,
                  color: Colors.black87,
                ),
                title: const Text("基础个人信息", style: TextStyle(fontSize: 15)),
                subtitle: Text(
                  "$gender | $birthYear年 | ${height.toInt()}cm | ${_formatWeight(currentWeight)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.black12,
                ),
                onTap: _showProfileEditSheet,
              ),
            ),

            _buildProfileItem(
              Icons.psychology_alt_outlined,
              'AI 对我的了解',
              '本地隐私',
              onTap: _showAiProfilePage,
            ),
            _buildProfileItem(Icons.workspace_premium_rounded, '高级版会员', '未开启'),
            _buildProfileItem(
              Icons.notifications_active_rounded,
              '提醒设置',
              '已开启',
            ),
            _buildProfileItem(Icons.security_rounded, '隐私保护', ''),
            _buildProfileItem(Icons.help_center_rounded, '帮助与反馈', ''),
            const SizedBox(height: 12),
            _buildProfileItem(
              Icons.info_outline_rounded,
              '关于 G O A T',
              'v1.2.0',
            ),

            const SizedBox(height: 24),
            if (isLoggedIn) ...[
              ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '退出当前账号',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              // 🌟 加入合规注销账号的入口
              TextButton(
                onPressed: _deleteAccount,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '注销账号并清空数据',
                  style: TextStyle(
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAiProfilePage() async {
    final storage = _storage;
    if (storage == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AiProfilePage(
          preferences: storage.prefs,
          namespace: _activeNamespace,
          trainingSessions: List.unmodifiable(allTrainingSessions),
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    IconData icon,
    String title,
    String trailing, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Colors.black54),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const Spacer(),
              Text(
                trailing,
                style: const TextStyle(fontSize: 14, color: Colors.black38),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 高级滚动轮盘个人信息编辑面板 ---
  void _showProfileEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "编辑基础信息",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildEditRow("性别", gender, () {
                  _showSingleWheelPicker(["男", "女"], gender == "女" ? 1 : 0, (
                    idx,
                  ) {
                    setState(() => gender = ["男", "女"][idx]);
                    _saveData();
                    setModalState(() {});
                  });
                }),
                const Divider(height: 24),
                _buildEditRow("生日", "$birthYear-$birthMonth-$birthDay", () {
                  _showBirthdayPicker((y, m, d) {
                    setState(() {
                      birthYear = y;
                      birthMonth = m;
                      birthDay = d;
                    });
                    _saveData();
                    setModalState(() {});
                  });
                }),
                const Divider(height: 24),
                _buildEditRow("身高", "${height.toInt()} cm", () {
                  _showSingleWheelPicker(
                    List.generate(161, (i) => "${90 + i} cm"),
                    (height - 90).toInt().clamp(0, 160),
                    (idx) {
                      setState(() => height = (90 + idx).toDouble());
                      _saveData();
                      setModalState(() {});
                    },
                  );
                }),
                const Divider(height: 24),
                _buildEditRow("体重", _formatWeight(currentWeight), () {
                  showWeightPickerSheet(
                    context: context,
                    initialWeight: currentWeight,
                    onSaved: (val) {
                      final change = applyWeightChange(
                        dailyWeight: dailyWeight,
                        date: todayStr,
                        today: todayStr,
                        currentWeight: currentWeight,
                        value: val,
                      );
                      setState(() {
                        currentWeight = change.currentWeight;
                        dailyWeight = change.dailyWeight;
                      });
                      _saveData();
                      setModalState(() {});
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditRow(String label, String val, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          Row(
            children: [
              Text(
                val,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GoatApp.marsGreen,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 16, color: Colors.black26),
            ],
          ),
        ],
      ),
    );
  }

  void _showSingleWheelPicker(
    List<String> items,
    int initialIndex,
    Function(int) onSave,
  ) {
    int tempIdx = initialIndex;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "取消",
                    style: TextStyle(color: Colors.black38),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    onSave(tempIdx);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "确定",
                    style: TextStyle(
                      color: GoatApp.marsGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: tempIdx,
                ),
                itemExtent: 40,
                onSelectedItemChanged: (i) => tempIdx = i,
                children: items.map((e) => Center(child: Text(e))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBirthdayPicker(Function(int, int, int) onSave) {
    int tempY = birthYear, tempM = birthMonth, tempD = birthDay;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "取消",
                    style: TextStyle(color: Colors.black38),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    onSave(tempY, tempM, tempD);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "确定",
                    style: TextStyle(
                      color: GoatApp.marsGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: tempY - 1900,
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => tempY = 1900 + i,
                      children: List.generate(
                        127,
                        (i) => Center(child: Text("${1900 + i}年")),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: tempM - 1,
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => tempM = 1 + i,
                      children: List.generate(
                        12,
                        (i) => Center(child: Text("${1 + i}月")),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: tempD - 1,
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => tempD = 1 + i,
                      children: List.generate(
                        31,
                        (i) => Center(child: Text("${1 + i}日")),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planStatItem(String label, int value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }

  // ============================================================================
  // 5. 局部 UI 组件构建
  // ============================================================================
  Widget _buildMacronutrientsCard(
    DailyMacroStats stats, {
    bool showEditSettings = false,
  }) {
    double netKcal = stats.kcalIn - stats.burn;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '今日摄入 (kcal)',
                style: TextStyle(
                  color: Colors.black26,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${stats.kcalIn.toInt()}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: GoatApp.marsGreen,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniStat('摄入', stats.kcalIn.toInt(), Colors.black87),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('-', style: TextStyle(color: Colors.black26)),
                  ),
                  _miniStat('消耗', stats.burn.toInt(), Colors.black87),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('=', style: TextStyle(color: Colors.black26)),
                  ),
                  _miniStat('净摄入', netKcal.toInt(), GoatApp.marsGreen),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('/', style: TextStyle(color: Colors.black26)),
                  ),
                  _miniStat('目标', targetKcal.toInt(), Colors.black38),
                ],
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _semiCircleWithLabel(
                        'PRO',
                        stats.p,
                        targetP,
                        GoatApp.marsGreen,
                      ),
                    ),
                    Expanded(
                      child: _semiCircleWithLabel(
                        'CHO',
                        stats.c,
                        targetC,
                        const Color(0xFF4DB6AC),
                      ),
                    ),
                    Expanded(
                      child: _semiCircleWithLabel(
                        'FAT',
                        stats.f,
                        targetF,
                        const Color(0xFF80CBC4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showEditSettings)
            Positioned(
              right: -10,
              top: -10,
              child: IconButton(
                icon: const Icon(
                  Icons.tune_rounded,
                  color: Colors.black26,
                  size: 20,
                ),
                onPressed: _showTargetSettingsDialog,
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int val, Color col) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black26)),
      Text(
        '$val',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: col),
      ),
    ],
  );

  Widget _semiCircleWithLabel(
    String title,
    double current,
    double target,
    Color color,
  ) {
    double progress = target > 0 ? (current / target) : 0;
    if (progress > 1.0) progress = 1.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          height: 35,
          child: CustomPaint(
            painter: SemiCirclePainter(progress: progress, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          '${current.toInt()}/${target.toInt()}g',
          style: const TextStyle(
            fontSize: 9,
            color: Colors.black54,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildWaterWeightRow(int water, double weight) {
    return Row(
      children: [
        Expanded(
          child: _buildDataCard(
            '饮水 (ml)',
            '${water == 0 ? '--' : water}',
            Icons.water_drop_outlined,
            Colors.blueAccent,
            () => _showWaterTrackingPage(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDataCard(
            '体重 (kg)',
            weight == 0 ? '--' : _formatWeight(weight),
            Icons.monitor_weight_outlined,
            Colors.orangeAccent,
            () => _showWeightPickerForDate(),
          ),
        ),
      ],
    );
  }

  Future<void> _showWaterTrackingPage() async {
    await showWaterTrackingPage(
      context: context,
      date: viewDateStr,
      repository: this,
      onTotalChanged: (_) {
        if (mounted) setState(() {});
      },
    );
  }

  void _showWeightPickerForDate() {
    final initial = dailyWeight[viewDateStr] ?? currentWeight;
    showWeightPickerSheet(
      context: context,
      initialWeight: initial,
      onSaved: (value) {
        final change = applyWeightChange(
          dailyWeight: dailyWeight,
          date: viewDateStr,
          today: todayStr,
          currentWeight: currentWeight,
          value: value,
        );
        setState(() {
          dailyWeight = change.dailyWeight;
          currentWeight = change.currentWeight;
        });
        _saveData();
      },
    );
  }

  Widget _buildDataCard(
    String title,
    String val,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  val,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietGrid(List<ConsumedRecord> consumed) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMealCard(
                '早餐',
                consumed.where((e) => e.mealType == '早餐').toList(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMealCard(
                '午餐',
                consumed.where((e) => e.mealType == '午餐').toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMealCard(
                '晚餐',
                consumed.where((e) => e.mealType == '晚餐').toList(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMealCard(
                '加餐/补剂',
                consumed
                    .where(
                      (e) =>
                          e.mealType != '早餐' &&
                          e.mealType != '午餐' &&
                          e.mealType != '晚餐',
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMealCard(String title, List<ConsumedRecord> meals) {
    double mealKcal = meals.fold(0, (sum, item) => sum + item.kcal);
    return GestureDetector(
      onTap: () => _showMealDetailPopup(title, title, meals),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${mealKcal.toInt()} kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    color: GoatApp.marsGreen,
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: '快速记录',
              onPressed: () => _showFoodPicker(context, title),
              icon: const Icon(
                Icons.add_circle_outline,
                color: GoatApp.marsGreen,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSection(
    List<ExerciseRecord> exercises,
    double totalBurn,
  ) {
    return GestureDetector(
      onTap: _showExerciseAddDialog,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.deepOrangeAccent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '运动消耗',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '-${totalBurn.toInt()} kcal',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.deepOrangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.add_circle,
                      color: GoatApp.marsGreen,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
            if (exercises.isNotEmpty) ...[
              const Divider(height: 24, color: Color(0xFFF5F5F5)),
              ...exercises.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Slidable(
                    key: ValueKey(e.id),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      extentRatio: 0.25,
                      children: [
                        CustomSlidableAction(
                          onPressed: (ctx) {
                            setState(() => allExerciseItems.remove(e));
                            _queueExerciseDelete(e.id);
                            _saveData();
                          },
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.type,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${e.startTime} - ${e.endTime}',
                              style: const TextStyle(
                                color: Colors.black38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '-${e.kcal.toInt()} kcal',
                          style: const TextStyle(
                            color: Colors.deepOrangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConciseGroupCard(
    String title,
    IconData icon,
    List<Widget> subSections,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Icon(icon, color: GoatApp.marsGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          ...subSections.map(
            (w) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: w,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSubGroup(
    String title,
    List<ConsumedRecord> items,
    VoidCallback onAdd,
  ) {
    double totalKcal = items.fold(0, (sum, i) => sum + i.kcal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${totalKcal.toInt()} kcal',
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle,
                color: GoatApp.marsGreen,
                size: 22,
              ),
              onPressed: onAdd,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        if (items.isNotEmpty) const SizedBox(height: 8),
        ...items.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    e.name,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${e.kcal.toInt()} kcal',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 16, color: Color(0xFFF5F5F5)),
      ],
    );
  }

  Widget _buildTargetSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            GestureDetector(
              onTap: () {
                final ctrl = TextEditingController(
                  text: value.toInt().toString(),
                );
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    title: Text(
                      '自定义 $label',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '输入具体数值',
                        filled: true,
                        fillColor: Color(0xFFF4F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '取消',
                          style: TextStyle(color: Colors.black38),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          double? val = double.tryParse(ctrl.text);
                          if (val != null) {
                            onChanged(val);
                          }
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '确认',
                          style: TextStyle(
                            color: GoatApp.marsGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: GoatApp.marsGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.toInt()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: GoatApp.marsGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: GoatApp.marsGreen,
            inactiveTrackColor: const Color(0xFFF0F0F0),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6,
              elevation: 2,
            ),
            overlayColor: GoatApp.marsGreen.withOpacity(0.1),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(7, (index) {
          bool isSelected = selectedDay == (index + 1);
          return GestureDetector(
            onTap: () => setState(() => selectedDay = index + 1),
            child: Container(
              margin: const EdgeInsets.only(right: 8, top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? GoatApp.marsGreen : const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '周${index + 1}',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================================
  // 6. DeepSeek 食物搜索与分类列表
  // ============================================================================
  List<FoodItem> _historyFoodItems() {
    final result = <FoodItem>[];
    final seen = <String>{};
    for (final record in allConsumedItems) {
      final key = record.name.trim();
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(
        FoodItem(
          id: 'history_$key',
          name: key,
          protein: record.amount > 0
              ? record.p * 100 / record.amount
              : record.p,
          carbs: record.amount > 0 ? record.c * 100 / record.amount : record.c,
          fat: record.amount > 0 ? record.f * 100 / record.amount : record.f,
          calories: record.amount > 0
              ? record.kcal * 100 / record.amount
              : record.kcal,
          category: '其他',
          unit: record.unit,
          weightPerUnit: record.unit.isEmpty ? 0 : record.amount,
        ),
      );
    }
    return result;
  }

  String _displayFoodCategory(String category) {
    if (category == '蔬果') return '蔬菜';
    if (category == '饮品') return '饮料';
    if (category == '肉类' || category == '蛋奶') return '肉蛋奶';
    if (category == '补剂') return '其他';
    return category;
  }

  List<FoodItem> _pickerFoods() {
    final result = <FoodItem>[];
    final seen = <String>{};
    void addAll(Iterable<FoodItem> foods) {
      for (final food in foods) {
        final key = food.name.trim();
        if (key.isNotEmpty && seen.add(key)) result.add(food);
      }
    }

    addAll(foodDatabase);
    addAll(_historyFoodItems());
    addAll(buildBuiltinFoodDatabase());
    return result;
  }

  List<FoodItem> _recentFoodPickerItems(String mealType) {
    return _nutritionQuickAccessService
        .recentFoods(records: allConsumedItems, mealType: mealType)
        .map(
          (food) => FoodItem(
            id: 'recent_${food.normalizedKey}',
            name: food.displayName,
            protein: food.amount > 0 ? food.protein * 100 / food.amount : 0,
            carbs: food.amount > 0 ? food.carbs * 100 / food.amount : 0,
            fat: food.amount > 0 ? food.fat * 100 / food.amount : 0,
            calories: food.amount > 0 ? food.kcal * 100 / food.amount : 0,
            category: '最近吃过',
            unit: food.unit,
            weightPerUnit: food.unit.isEmpty ? 0 : food.amount,
          ),
        )
        .toList();
  }

  void _showFoodPicker(BuildContext context, String mealType) {
    final searchCtrl = TextEditingController();
    List<FoodItem>? searchResults;
    final categories = ['最近吃过', '全部', '主食', '肉蛋奶', '蔬菜', '水果', '饮料', '其他'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void performSearch(String kw) async {
            final query = kw.trim();
            if (query.isEmpty) return;
            final localMatches = _pickerFoods()
                .followedBy(_recentFoodPickerItems(mealType))
                .where((food) => food.name.contains(query))
                .toList();
            if (localMatches.isNotEmpty) {
              setModalState(() => searchResults = localMatches);
              return;
            }
            await _searchFoodWithDeepSeek(kw, setModalState);
            setModalState(() => searchResults = null);
            searchCtrl.clear();
          }

          return DefaultTabController(
            length: categories.length,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '录入 $mealType',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 0,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showCopyYesterdaySheet(mealType);
                              },
                              icon: const Icon(Icons.copy_outlined, size: 16),
                              label: const Text('复制昨日'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black45,
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _showAddCustomFoodDialog(setModalState),
                              icon: const Icon(Icons.edit_note, size: 16),
                              label: const Text('自定义食物'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black45,
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                unawaited(
                                  showVoiceEntrySheet(
                                    context: this.context,
                                    mealType: mealType,
                                    speechService: _speechService,
                                    nutritionService: _nutritionAiService,
                                    repository: this,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('AI录入'),
                              style: TextButton.styleFrom(
                                foregroundColor: GoatApp.marsGreen,
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: performSearch,
                      decoration: InputDecoration(
                        hintText: '问问 DeepSeek，例如：1个汉堡...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.black26,
                        ),
                        prefixIcon: const Icon(
                          Icons.auto_awesome,
                          color: GoatApp.marsGreen,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),

                  if (searchHistory.isNotEmpty && !_isSearching)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "最近搜索",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() => searchHistory.clear());
                                  _saveLocalPreferencesOnly();
                                  setModalState(() {});
                                },
                                child: const Text(
                                  "清空记录",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: searchHistory
                                  .map(
                                    (query) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ActionChip(
                                        label: Text(
                                          query,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        backgroundColor: const Color(
                                          0xFFF4F5F7,
                                        ),
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        onPressed: () => performSearch(query),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: GoatApp.marsGreen,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: GoatApp.marsGreen,
                    indicatorSize: TabBarIndicatorSize.label,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: categories.map((c) => Tab(text: c)).toList(),
                  ),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),

                  Expanded(
                    child: _isSearching
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: GoatApp.marsGreen,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'DeepSeek 正在估算营养成分...',
                                  style: TextStyle(
                                    color: Colors.black38,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TabBarView(
                            children: categories.map((cat) {
                              final filteredList =
                                  (searchResults ??
                                          (cat == '最近吃过'
                                              ? _recentFoodPickerItems(mealType)
                                              : _pickerFoods()))
                                      .where(
                                        (f) =>
                                            searchResults != null ||
                                            cat == '全部' ||
                                            _displayFoodCategory(f.category) ==
                                                cat,
                                      )
                                      .toList();

                              if (filteredList.isEmpty) {
                                return Center(
                                  child: Text(
                                    cat == '最近吃过'
                                        ? '完成一次饮食记录后，常用食物会显示在这里'
                                        : '该分类暂无食物\n快在上方呼叫 DeepSeek 扩充吧！',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.black26,
                                      height: 1.5,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final f = filteredList[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Slidable(
                                      key: ValueKey(f.name + index.toString()),
                                      endActionPane:
                                          f.id.startsWith('builtin_') ||
                                              f.id.startsWith('history_')
                                          ? null
                                          : ActionPane(
                                              motion: const ScrollMotion(),
                                              extentRatio: 0.25,
                                              children: [
                                                CustomSlidableAction(
                                                  onPressed: (ctx) {
                                                    setState(() {
                                                      foodDatabase.remove(f);
                                                    });
                                                    _queueFoodDelete(f.id);
                                                    _saveData();
                                                    setModalState(() {});
                                                  },
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                  foregroundColor: Colors.white,
                                                  child: const Icon(
                                                    Icons.delete,
                                                  ),
                                                ),
                                              ],
                                            ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F5F7),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            f.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '标准: ${f.calories.toInt()}kcal/100g | P:${f.protein} C:${f.carbs} F:${f.fat}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                              if (f.unit.isNotEmpty &&
                                                  f.weightPerUnit > 0)
                                                Text(
                                                  '量词: 1${f.unit} (约${f.weightPerUnit.toInt()}g) = ${(f.calories * f.weightPerUnit / 100).toInt()} kcal',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: GoatApp.marsGreen,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.add_circle,
                                              color: GoatApp.marsGreen,
                                            ),
                                            onPressed: () =>
                                                _showAddFoodAmountDialog(
                                                  f,
                                                  mealType,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _searchFoodWithDeepSeek(
    String foodName,
    Function setModalState,
  ) async {
    setState(() {
      searchHistory.remove(foodName);
      searchHistory.insert(0, foodName);
      if (searchHistory.length > 10) searchHistory.removeLast();
    });
    _saveLocalPreferencesOnly();

    setModalState(() => _isSearching = true);
    if (!_allowDirectDebugAi) {
      _rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('AI 食物搜索需先完成服务端配置')),
      );
      setModalState(() => _isSearching = false);
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse('https://api.deepseek.com/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $deepSeekApiKey',
            },
            body: json.encode({
              "model": "deepseek-chat",
              "response_format": {"type": "json_object"},
              "messages": [
                {
                  "role": "system",
                  "content":
                      "你是一个精确的食物营养计算API。无论用户输入什么食物，请严格估算并返回该食物【每100克】的基础营养成分。如果用户输入包含具体的量词（如'一个'、'一份'），请估算该单一量词对应的实际重量（克）。分类必须是：主食、肉蛋奶、蔬果、饮品、补剂其中之一。必须返回合法JSON：{\"name\": \"名称\", \"protein\": 每100g蛋白质(数字), \"carbs\": 每100g碳水(数字), \"fat\": 每100g脂肪(数字), \"calories\": 每100g热量(数字), \"category\": \"分类\", \"unit\": \"提取到的量词(如'个','份')，若无则为空字符串\", \"weightPerUnit\": 该量词对应的克数(数字，若无则为0)}。不要有任何额外文本。",
                },
                {"role": "user", "content": foodName},
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final result = json.decode(utf8.decode(response.bodyBytes));
        final Map<String, dynamic> foodData = json.decode(
          result['choices'][0]['message']['content'],
        );
        final FoodItem aiFood = FoodItem.fromJson(foodData);

        setState(() {
          foodDatabase.removeWhere((item) => item.name == aiFood.name);
          foodDatabase.insert(0, aiFood);
        });
        _saveData();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("DeepSeek 响应异常，请重试")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("网络异常: $e")));
    } finally {
      setModalState(() => _isSearching = false);
    }
  }

  void _showAddFoodAmountDialog(FoodItem f, String mealType) {
    bool hasUnit = f.unit.isNotEmpty && f.weightPerUnit > 0;
    bool useUnitMode = hasUnit;
    double selectedAmount = useUnitMode ? 1.0 : 100.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateLocal) {
          double realWeightGrams = useUnitMode
              ? (selectedAmount * f.weightPerUnit)
              : selectedAmount;
          double ratio = realWeightGrams / 100.0;
          double realKcal = f.calories * ratio;
          double realP = f.protein * ratio;
          double realC = f.carbs * ratio;
          double realF = f.fat * ratio;

          return SizedBox(
            height: 420,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '取消',
                          style: TextStyle(color: Colors.black38),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          '吃多少 ${f.name}?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            allConsumedItems.insert(
                              0,
                              ConsumedRecord(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                name:
                                    '${f.name} (${selectedAmount.toInt()}${useUnitMode ? f.unit : 'g'})',
                                p: realP,
                                c: realC,
                                f: realF,
                                kcal: realKcal,
                                mealType: mealType,
                                date: viewDateStr,
                                amount: selectedAmount,
                                unit: useUnitMode ? f.unit : 'g',
                              ),
                            );
                          });
                          _saveData();
                          Navigator.pop(context);
                          Navigator.pop(context);
                          _showMealDetailPopup(
                            mealType,
                            mealType,
                            allConsumedItems
                                .where(
                                  (i) =>
                                      i.mealType == mealType &&
                                      i.date == viewDateStr,
                                )
                                .toList(),
                          );
                        },
                        child: const Text(
                          '确定吃',
                          style: TextStyle(
                            color: GoatApp.marsGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (hasUnit)
                  CupertinoSegmentedControl<bool>(
                    groupValue: useUnitMode,
                    selectedColor: GoatApp.marsGreen,
                    borderColor: GoatApp.marsGreen,
                    children: {
                      true: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text("按${f.unit}"),
                      ),
                      false: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("按克(g)"),
                      ),
                    },
                    onValueChanged: (val) {
                      setStateLocal(() {
                        useUnitMode = val;
                        selectedAmount = useUnitMode ? 1 : 100;
                      });
                    },
                  ),

                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '实际摄入: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${realKcal.toInt()}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: GoatApp.marsGreen,
                            ),
                          ),
                          const Text(
                            ' kcal',
                            style: TextStyle(
                              fontSize: 12,
                              color: GoatApp.marsGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniStat('P (g)', realP.toInt(), Colors.black87),
                          _miniStat('C (g)', realC.toInt(), Colors.black87),
                          _miniStat('F (g)', realF.toInt(), Colors.black87),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: CupertinoPicker(
                    key: ValueKey(useUnitMode),
                    scrollController: FixedExtentScrollController(
                      initialItem: useUnitMode
                          ? (selectedAmount.toInt() - 1)
                          : (selectedAmount ~/ 10),
                    ),
                    itemExtent: 45.0,
                    backgroundColor: Colors.white,
                    onSelectedItemChanged: (int index) {
                      setStateLocal(() {
                        selectedAmount = useUnitMode
                            ? (index + 1).toDouble()
                            : (index * 10).toDouble();
                      });
                    },
                    children: List<Widget>.generate(
                      useUnitMode ? 50 : 200,
                      (int index) => Center(
                        child: Text(
                          '${useUnitMode ? (index + 1) : (index * 10)} ${useUnitMode ? f.unit : 'g'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLegacyRecordDialog(String title, double current, bool isWeight) {
    /* Legacy aggregate picker removed; weight and water use shared pages.
    int step = isWeight ? 1 : 50;
    double tempValue = current == 0 ? (isWeight ? 60.0 : 200.0) : current;
    int initialIndex = isWeight ? tempValue.toInt() : (tempValue ~/ step);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.black38),
                    ),
                  ),
                  Text(
                    '记录 $title',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (isWeight) {
                          dailyWeight[viewDateStr] = tempValue;
                          if (viewDateStr == todayStr)
                            currentWeight = tempValue;
                        }
                      });
                      _saveData();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      '确定',
                      style: TextStyle(color: GoatApp.marsGreen),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: initialIndex,
                ),
                itemExtent: 45.0,
                onSelectedItemChanged: (int index) => tempValue = isWeight
                    ? index.toDouble()
                    : (index * step).toDouble(),
                children: List<Widget>.generate(
                  isWeight ? 300 : 100,
                  (int index) => Center(
                    child: Text(
                      '${isWeight ? index : index * step} ${isWeight ? 'kg' : 'ml'}',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    */
  }

  Future<void> _showNutritionQuickAdd([String mealType = '加餐']) async {
    final recentFoods = _nutritionQuickAccessService.recentFoods(
      records: allConsumedItems,
      mealType: mealType,
    );
    await showNutritionQuickAddSheet(
      context: context,
      mealType: mealType,
      recentFoods: recentFoods,
      repository: this,
      nutritionService: _nutritionAiService,
      speechService: _speechService,
      enableSystemSpeech: enableSystemSpeechRecognition,
      onAddRecent: (suggestion, amount, selectedMealType) async {
        final ratio = amount / suggestion.amount;
        await addConsumedRecords([
          ConsumedRecord(
            id: '',
            name: suggestion.displayName,
            p: suggestion.protein * ratio,
            c: suggestion.carbs * ratio,
            f: suggestion.fat * ratio,
            kcal: suggestion.kcal * ratio,
            mealType: selectedMealType,
            date: viewDateStr,
            amount: amount,
            unit: suggestion.unit,
          ),
        ]);
      },
      onCopyYesterday: () {
        _showCopyYesterdaySheet(mealType);
      },
      onCustomFood: () {
        _showFoodPicker(this.context, mealType);
      },
    );
  }

  Future<void> _showCopyYesterdaySheet(String? mealType) async {
    final copyAll = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('复制昨日'),
        content: const Text('选择复制范围'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('当前餐次'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('全天饮食'),
          ),
        ],
      ),
    );
    if (copyAll == null) return;
    final date = DateUtils.dateOnly(
      DateTime.tryParse(viewDateStr) ?? DateTime.now(),
    ).subtract(const Duration(days: 1));
    final sourceDate = _dateKey(date);
    final plan = _nutritionQuickAccessService.copyPlan(
      records: allConsumedItems,
      sourceDate: sourceDate,
      mealType: copyAll ? null : mealType,
    );
    await showCopyDietSheet(
      context: context,
      plan: plan,
      targetDate: viewDateStr,
      onConfirm: (records) async {
        final copies = records
            .map(
              (record) => ConsumedRecord(
                id: '',
                name: record.name,
                p: record.p,
                c: record.c,
                f: record.f,
                kcal: record.kcal,
                mealType: record.mealType,
                date: viewDateStr,
                amount: record.amount,
                unit: record.unit,
              ),
            )
            .toList();
        await addConsumedRecords(copies);
      },
    );
  }

  void _showExerciseAddDialog() {
    String type = '有氧运动';
    final now = TimeOfDay.now();
    final startController = TextEditingController(
      text:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '45');
    final kcalController = TextEditingController();
    String? error;

    final route = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final hours = int.tryParse(hoursController.text) ?? 0;
          final minutes = int.tryParse(minutesController.text) ?? 0;
          ExerciseEndTime? endTime;
          try {
            endTime = calculateExerciseEndTime(
              startTime: startController.text,
              hours: hours,
              minutes: minutes,
            );
          } on FormatException {
            endTime = null;
          }
          final endLabel = endTime == null
              ? '--'
              : '${endTime.isNextDay ? '次日 ' : ''}${endTime.value}';

          void refresh() => setModalState(() => error = null);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '记录运动',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: ['有氧运动', '无氧运动']
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value),
                            selected: type == value,
                            onSelected: (_) =>
                                setModalState(() => type = value),
                            selectedColor: GoatApp.marsGreen.withOpacity(0.12),
                            labelStyle: TextStyle(
                              color: type == value
                                  ? GoatApp.marsGreen
                                  : Colors.black54,
                            ),
                            showCheckmark: false,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: startController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [TimeTextInputFormatter()],
                    onChanged: (_) => refresh(),
                    decoration: const InputDecoration(
                      labelText: '开始时间',
                      hintText: '11:41',
                      filled: true,
                      fillColor: Color(0xFFF4F5F7),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hoursController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => refresh(),
                          decoration: const InputDecoration(
                            labelText: '运动时长（小时）',
                            filled: true,
                            fillColor: Color(0xFFF4F5F7),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: minutesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => refresh(),
                          decoration: const InputDecoration(
                            labelText: '运动时长（分钟）',
                            filled: true,
                            fillColor: Color(0xFFF4F5F7),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '预计结束  $endLabel',
                    style: const TextStyle(
                      color: GoatApp.marsGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kcalController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => refresh(),
                    decoration: const InputDecoration(
                      labelText: '消耗热量 (kcal)',
                      filled: true,
                      fillColor: Color(0xFFF4F5F7),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      final kcal = double.tryParse(kcalController.text.trim());
                      if (endTime == null || kcal == null || kcal < 0) {
                        setModalState(() => error = '请检查时间、时长和消耗热量');
                        return;
                      }
                      setState(
                        () => allExerciseItems.insert(
                          0,
                          ExerciseRecord(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            type: type,
                            kcal: kcal,
                            startTime: startController.text,
                            endTime: endLabel,
                            date: viewDateStr,
                          ),
                        ),
                      );
                      _saveData();
                      Navigator.pop(sheetContext);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: GoatApp.marsGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('保存记录'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    route.whenComplete(() {
      startController.dispose();
      hoursController.dispose();
      minutesController.dispose();
      kcalController.dispose();
    });
  }

  void _showLegacyExerciseAddDialog() {
    String type = '有氧运动';
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay.now();
    final kcalCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '记录运动',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['有氧运动', '无氧运动']
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ChoiceChip(
                          label: Text(t),
                          selected: type == t,
                          onSelected: (val) => setModalState(() => type = t),
                          selectedColor: GoatApp.marsGreen.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: type == t
                                ? GoatApp.marsGreen
                                : Colors.black38,
                            fontWeight: type == t
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          side: BorderSide.none,
                          showCheckmark: false,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '开始: ${startTime.format(context)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '结束: ${endTime.format(context)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: kcalCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '消耗热量 (kcal)',
                  prefixIcon: const Icon(
                    Icons.local_fire_department,
                    color: Colors.deepOrangeAccent,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (kcalCtrl.text.isNotEmpty) {
                      setState(
                        () => allExerciseItems.insert(
                          0,
                          ExerciseRecord(
                            id: DateTime.now().toString(),
                            type: type,
                            kcal: double.parse(kcalCtrl.text),
                            startTime: startTime.format(context),
                            endTime: endTime.format(context),
                            date: viewDateStr,
                          ),
                        ),
                      );
                      _saveData();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GoatApp.marsGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '保存记录',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showMealDetailPopup(
    String title,
    String mealType,
    List<ConsumedRecord> items,
  ) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) {
          double totalKcal = items.fold(0, (sum, i) => sum + i.kcal);
          double totalP = items.fold(0, (sum, i) => sum + i.p);
          double totalC = items.fold(0, (sum, i) => sum + i.c);
          double totalF = items.fold(0, (sum, i) => sum + i.f);
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            contentPadding: const EdgeInsets.all(20),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: GoatApp.marsGreen),
                  onPressed: () {
                    Navigator.pop(context);
                    _showFoodPicker(this.context, mealType);
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat(
                        '总计 kcal',
                        totalKcal.toInt(),
                        GoatApp.marsGreen,
                      ),
                      _miniStat('P (g)', totalP.toInt(), Colors.black87),
                      _miniStat('C (g)', totalC.toInt(), Colors.black87),
                      _miniStat('F (g)', totalF.toInt(), Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFEEE)),
                  const SizedBox(height: 16),

                  // ==========================================
                  // 🌟 新增：AI 语音录入按钮完美嵌入此处
                  // ==========================================
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showFoodPicker(this.context, mealType);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: GoatApp.marsGreen,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: GoatApp.marsGreen.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "AI 饮食快速记录",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "例如：中午吃了一个煎饼果子",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.edit_note_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  if (items.isEmpty)
                    const Text('暂无记录', style: TextStyle(color: Colors.black26))
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Slidable(
                          key: ValueKey(item.id),
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            extentRatio: 0.3,
                            children: [
                              CustomSlidableAction(
                                onPressed: (ctx) {
                                  unawaited(deleteRecord(item.id));
                                  items.remove(item);
                                  setPopupState(() {});
                                },
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                child: const Icon(Icons.delete),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(context);
                                showEditDietRecordSheet(
                                  context: this.context,
                                  record: item,
                                  onSave: updateRecord,
                                );
                              },
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Text(
                                '${item.kcal.toInt()} kcal',
                                style: const TextStyle(
                                  color: GoatApp.marsGreen,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddCustomFoodDialog(Function setModalState) {
    final nameCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final fCtrl = TextEditingController();
    final kCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('自定义食物 (每100g)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '食物名称'),
              ),
              TextField(
                controller: pCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '蛋白质 (g)'),
              ),
              TextField(
                controller: cCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '碳水 (g)'),
              ),
              TextField(
                controller: fCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '脂肪 (g)'),
              ),
              TextField(
                controller: kCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '热量 (kcal)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.black38)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(
                  () => foodDatabase.add(
                    FoodItem(
                      name: nameCtrl.text,
                      protein: double.tryParse(pCtrl.text) ?? 0,
                      carbs: double.tryParse(cCtrl.text) ?? 0,
                      fat: double.tryParse(fCtrl.text) ?? 0,
                      calories: double.tryParse(kCtrl.text) ?? 0,
                      category: '主食',
                    ),
                  ),
                );
                _saveData();
                setModalState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text('保存', style: TextStyle(color: GoatApp.marsGreen)),
          ),
        ],
      ),
    );
  }

  // 🌟 新增：在历史页展示单日训练总结
  Widget _buildDailyTrainingSummary(String dateStr) {
    // 筛选出选中日期的所有训练课
    final sessions = allTrainingSessions
        .where((s) => s.date == dateStr)
        .toList();
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                size: 20,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              const Text(
                "今日运动",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                "${sessions.length} 场训练",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          // 简洁列出训练项目
          ...sessions
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "${s.exercises.length} 动作 | ${s.sessionVolume.toInt()} kg 容量",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  void _showTargetSettingsDialog() {
    final kCtrl = TextEditingController(text: targetKcal.toInt().toString());
    final pCtrl = TextEditingController(text: targetP.toInt().toString());
    final cCtrl = TextEditingController(text: targetC.toInt().toString());
    final fCtrl = TextEditingController(text: targetF.toInt().toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '修改今日全局目标',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: kCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '热量 (kcal)',
                prefixIcon: const Icon(
                  Icons.local_fire_department,
                  color: Colors.deepOrangeAccent,
                ),
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '蛋白质 (g)',
                      prefixIcon: const Icon(
                        Icons.fitness_center,
                        color: Colors.black54,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: cCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '碳水 (g)',
                      prefixIcon: const Icon(
                        Icons.grass,
                        color: Colors.black54,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: fCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '脂肪 (g)',
                prefixIcon: const Icon(
                  Icons.water_drop_outlined,
                  color: Colors.black54,
                ),
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    targetKcal = double.tryParse(kCtrl.text) ?? 2000;
                    targetP = double.tryParse(pCtrl.text) ?? 150;
                    targetC = double.tryParse(cCtrl.text) ?? 200;
                    targetF = double.tryParse(fCtrl.text) ?? 60;
                  });
                  _saveData();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GoatApp.marsGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text(
                  '保 存',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 8. DeepSeek 教练专属对话页面
// ============================================================================
class ChatAssistantPage extends StatefulWidget {
  final String userData;
  const ChatAssistantPage({super.key, required this.userData});
  @override
  State<ChatAssistantPage> createState() => _ChatAssistantPageState();
}

class _ChatAssistantPageState extends State<ChatAssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String deepSeekApiKey = const String.fromEnvironment(
    'DEEPSEEK_API_KEY',
  );
  bool get _allowDirectDebugAi =>
      kDebugMode &&
      const bool.fromEnvironment('GOAT_DEBUG_DIRECT_AI', defaultValue: false) &&
      deepSeekApiKey.trim().isNotEmpty;
  bool _isLoading = false;
  final supabase = Supabase.instance.client;
  List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages = [
      {
        "role": "assistant",
        "content":
            "你好！我是你的 DeepSeek 私人教练。我已经获取了你的身体基础数据，今天我可以帮你规划饮食热量，或者定制专属的健身动作。",
      },
    ];
    _loadHistoryFromCloud();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryFromCloud() async {
    final user = supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _messages = (json.decode(response['messages']) as List)
              .map((e) => Map<String, String>.from(e))
              .toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("加载聊天记录失败: $e");
    }
  }

  Future<void> _saveHistoryToCloud() async {
    final user = supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await supabase.from('chat_history').upsert({
        'user_id': user.id,
        'messages': json.encode(_messages),
      });
    } catch (e) {
      debugPrint("保存聊天记录失败: $e");
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    String userText = _controller.text.trim();
    setState(() {
      _messages.add({"role": "user", "content": userText});
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    if (!_allowDirectDebugAi) {
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "AI 教练服务正在通过服务端代理接入，请先完成服务端配置。",
          });
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('https://api.deepseek.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $deepSeekApiKey',
            },
            body: json.encode({
              "model": "deepseek-chat",
              "messages": [
                {
                  "role": "system",
                  "content":
                      "你是一位专业健身教练兼营养学专家。用户的个人基础数据如下：【${widget.userData}】。在给出饮食和运动建议时，必须严格结合这些身体数据进行个性化换算和分析。不要机械死板，要显得友善专业。",
                },
                ..._messages,
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 && mounted) {
        final result = json.decode(utf8.decode(response.bodyBytes));
        setState(
          () => _messages.add({
            "role": "assistant",
            "content": result['choices'][0]['message']['content'].trim(),
          }),
        );
        await _saveHistoryToCloud();
      }
    } catch (e) {
      debugPrint("DeepSeek 响应错误: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "清空对话",
          style: TextStyle(fontWeight: FontWeight.w400),
        ),
        content: const Text(
          "确定要清空与 DeepSeek 教练的对话记录吗？",
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消", style: TextStyle(color: Colors.black38)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages = [
                  {
                    "role": "assistant",
                    "content":
                        "你好！我是你的 DeepSeek 私人教练。我已经获取了你的身体基础数据，今天我可以帮你规划饮食热量，或者定制专属的健身动作。",
                  },
                ];
              });
              _saveHistoryToCloud();
              Navigator.pop(context);
            },
            child: const Text("清空", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text(
          "DeepSeek 教练",
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 18,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.cleaning_services_rounded,
              color: Colors.black38,
              size: 20,
            ),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: GoatApp.deepSeekBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: GoatApp.deepSeekBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isUser ? GoatApp.marsGreen : Colors.white,
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isUser
                                ? const Radius.circular(0)
                                : const Radius.circular(20),
                            bottomLeft: isUser
                                ? const Radius.circular(20)
                                : const Radius.circular(0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          msg['content']!,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            height: 1.5,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          child: const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Container(
              margin: const EdgeInsets.only(bottom: 16, left: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: GoatApp.deepSeekBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: GoatApp.deepSeekBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        20,
                      ).copyWith(topLeft: const Radius.circular(0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: GoatApp.deepSeekBlue,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "DeepSeek 正在思考...",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(fontWeight: FontWeight.w300),
                      decoration: InputDecoration(
                        hintText: "问问 DeepSeek 饮食和运动建议...",
                        hintStyle: const TextStyle(
                          color: Colors.black26,
                          fontWeight: FontWeight.w300,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: GoatApp.deepSeekBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. 图形组件
// ============================================================================
class AIRecommendationCard extends StatelessWidget {
  final String content;
  final VoidCallback? onClose;
  final bool isLoading; // 新增：是否正在加载
  const AIRecommendationCard({
    super.key,
    required this.content,
    this.onClose,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty && !isLoading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isLoading
                ? const Color(0xFFF0F0F0).withOpacity(0.9)
                : const Color(0xFFF0FDF4),
            Colors.white.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GoatApp.marsGreen.withOpacity(isLoading ? 0.05 : 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: GoatApp.marsGreen.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: GoatApp.marsGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: GoatApp.marsGreen,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome,
                            color: GoatApp.marsGreen,
                            size: 14,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "DeepSeek 饮食建议",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GoatApp.marsGreen.withOpacity(
                        isLoading ? 0.5 : 1.0,
                      ),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (onClose != null && !isLoading)
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.black26,
                  ),
                ),
              if (isLoading)
                const Icon(
                  Icons.hourglass_empty,
                  size: 16,
                  color: Colors.black12,
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              content,
              key: ValueKey(content),
              style: TextStyle(
                fontSize: 14,
                color: isLoading ? Colors.black38 : Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SemiCirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  SemiCirclePainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final paintProgress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height);
    final radius = (size.width / 2) - 5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      paintBase,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * progress,
      false,
      paintProgress,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// 🌟 1. 每日综合评分雷达图 Painter (图表5)
// ==========================================
class RadarScorePainter extends CustomPainter {
  final DailyMacroStats stats;
  final double tKcal, tP, tC, tF;
  RadarScorePainter(this.stats, this.tKcal, this.tP, this.tC, this.tF);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    int sides = 5;
    for (int step = 1; step <= 4; step++) {
      double r = radius * (step / 4);
      Path path = Path();
      for (int i = 0; i < sides; i++) {
        double angle = (math.pi * 2 * i / sides) - math.pi / 2;
        double x = center.dx + r * math.cos(angle);
        double y = center.dy + r * math.sin(angle);
        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, step == 4 ? bgPaint : strokePaint);
      canvas.drawPath(path, strokePaint);
    }

    double kcalScore = 1.0 - (stats.kcalIn - tKcal).abs() / tKcal;
    if (kcalScore < 0) kcalScore = 0.1;
    double pScore = math.min(stats.p / (tP > 0 ? tP : 1), 1.0);
    double cScore = math.min(stats.c / (tC > 0 ? tC : 1), 1.0);
    double fScore = math.min(stats.f / (tF > 0 ? tF : 1), 1.0);
    double burnScore = math.min(stats.burn / 500.0, 1.0);

    List<double> scores = [kcalScore, pScore, cScore, fScore, burnScore];
    List<String> labels = ["热量控制", "蛋白质", "碳水", "脂肪", "运动消耗"];

    Path dataPath = Path();
    final dataPaint = Paint()
      ..color = GoatApp.marsGreen.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    final dataStroke = Paint()
      ..color = GoatApp.marsGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < sides; i++) {
      double angle = (math.pi * 2 * i / sides) - math.pi / 2;
      double r = radius * scores[i];
      double x = center.dx + r * math.cos(angle);
      double y = center.dy + r * math.sin(angle);
      if (i == 0)
        dataPath.moveTo(x, y);
      else
        dataPath.lineTo(x, y);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      double lx =
          center.dx + (radius + 15) * math.cos(angle) - textPainter.width / 2;
      double ly =
          center.dy + (radius + 15) * math.sin(angle) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(lx, ly));
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, dataStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// 🌟 2. 营养构成堆叠柱状图 Painter (图表1)
// ==========================================
class MacroStackedBarPainter extends CustomPainter {
  final List<ConsumedRecord> data;
  final List<DateTime> dates;
  MacroStackedBarPainter(this.data, this.dates);

  @override
  void paint(Canvas canvas, Size size) {
    List<Map<String, double>> daysData = [];
    double maxKcal = 1;

    for (final date in dates) {
      String d =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      var dayItems = data.where((e) => e.date == d);
      double p = dayItems.fold(0.0, (sum, e) => sum + e.p) * 4; // 蛋白质 4Kcal/g
      double c = dayItems.fold(0.0, (sum, e) => sum + e.c) * 4; // 碳水 4Kcal/g
      double f = dayItems.fold(0.0, (sum, e) => sum + e.f) * 9; // 脂肪 9Kcal/g
      double total = p + c + f;
      if (total > maxKcal) maxKcal = total;
      daysData.add({'p': p, 'c': c, 'f': f, 'total': total});
    }

    if (maxKcal < 2000) maxKcal = 2000;
    final count = dates.length;
    double barWidth = math.max(3.0, size.width / (count * 1.8));
    double stepX = size.width / count;

    final pPaint = Paint()
      ..color = const Color(0xFF4D6BFE)
      ..style = PaintingStyle.fill;
    final cPaint = Paint()
      ..color = const Color(0xFFF6AD55)
      ..style = PaintingStyle.fill;
    final fPaint = Paint()
      ..color = const Color(0xFFF56565)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      double x = i * stepX + stepX / 2 - barWidth / 2;
      double pHeight = (daysData[i]['p']! / maxKcal) * size.height;
      double cHeight = (daysData[i]['c']! / maxKcal) * size.height;
      double fHeight = (daysData[i]['f']! / maxKcal) * size.height;

      double yF = size.height - fHeight;
      double yC = yF - cHeight;
      double yP = yC - pHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, yF, barWidth, fHeight),
          const Radius.circular(2),
        ),
        fPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, yC, barWidth, cHeight),
          const Radius.circular(2),
        ),
        cPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, yP, barWidth, pHeight),
          const Radius.circular(2),
        ),
        pPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// 🌟 3. 热量收支双向条形图 Painter (图表2)
// ==========================================
class CalorieDivergingBarPainter extends CustomPainter {
  final List<ConsumedRecord> consumed;
  final List<ExerciseRecord> exercise;
  final List<DateTime> dates;
  CalorieDivergingBarPainter(this.consumed, this.exercise, this.dates);

  @override
  void paint(Canvas canvas, Size size) {
    List<double> intakeData = [];
    List<double> burnData = [];
    double maxVal = 1;

    for (final date in dates) {
      String d =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      double intake = consumed
          .where((e) => e.date == d)
          .fold(0.0, (s, e) => s + e.kcal);
      double burn = exercise
          .where((e) => e.date == d)
          .fold(0.0, (s, e) => s + e.kcal);
      intakeData.add(intake);
      burnData.add(burn);
      if (intake > maxVal) maxVal = intake;
      if (burn > maxVal) maxVal = burn;
    }

    if (maxVal < 2000) maxVal = 2000;

    double centerY = size.height * 0.7;
    final count = dates.length;
    double barWidth = math.max(3.0, size.width / (count * 1.8));
    double stepX = size.width / count;

    final intakePaint = Paint()
      ..color = GoatApp.marsGreen
      ..style = PaintingStyle.fill;
    final burnPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;
    final axisPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      axisPaint,
    ); // 画 X 轴

    for (int i = 0; i < count; i++) {
      double x = i * stepX + stepX / 2 - barWidth / 2;
      // 摄入量（绿色，向上）
      double intakeH = (intakeData[i] / maxVal) * centerY;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, centerY - intakeH, barWidth, intakeH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        intakePaint,
      );
      // 运动消耗（橙色，向下）
      double burnH = (burnData[i] / maxVal) * (size.height - centerY);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, centerY, barWidth, burnH),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
        burnPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WeightTrendPainter extends CustomPainter {
  final Map<String, double> weights;
  final List<DateTime> dates;

  WeightTrendPainter(this.weights, this.dates);

  @override
  void paint(Canvas canvas, Size size) {
    final values = dates.map((date) {
      final value =
          weights['${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'];
      return value != null && value > 0 ? value : null;
    }).toList();
    final recorded = values.whereType<double>().toList();
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (recorded.isEmpty) return;

    double minValue = recorded.reduce(math.min) - 0.5;
    double maxValue = recorded.reduce(math.max) + 0.5;
    if (maxValue - minValue < 1) {
      minValue -= 0.5;
      maxValue += 0.5;
    }

    final stepX = size.width / math.max(1, dates.length - 1);
    final path = Path();
    bool hasPreviousPoint = false;
    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        hasPreviousPoint = false;
        continue;
      }
      final x = i * stepX;
      final y =
          size.height -
          ((value - minValue) / (maxValue - minValue) * size.height);
      if (hasPreviousPoint) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
      }
      hasPreviousPoint = true;
    }
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final x = i * stepX;
      final y =
          size.height -
          ((value - minValue) / (maxValue - minValue) * size.height);
      canvas.drawCircle(Offset(x, y), 3.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TrainingVolumePainter extends CustomPainter {
  final List<TrainingSession> sessions;
  final List<DateTime> dates;

  TrainingVolumePainter(this.sessions, this.dates);

  @override
  void paint(Canvas canvas, Size size) {
    final volumes = dates.map((date) {
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return sessions
          .where((session) => session.date == key)
          .fold(0.0, (sum, session) => sum + session.sessionVolume);
    }).toList();
    final maxVolume = math.max(1.0, volumes.fold(0.0, math.max));
    final count = dates.length;
    final stepX = size.width / count;
    final barWidth = math.max(3.0, size.width / (count * 1.8));
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.fill;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 0; i < count; i++) {
      final height = volumes[i] / maxVolume * size.height;
      final x = i * stepX + (stepX - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - height, barWidth, height),
          const Radius.circular(3),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;

  // 倒计时相关
  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // 开始 60 秒倒计时
  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // 1. 请求发送短信验证码
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 11) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的手机号')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 🌟 调用 Supabase 发送手机验证码
      // 注意：国内手机号通常需要加区号 +86
      await Supabase.instance.client.auth.signInWithOtp(phone: '+86$phone');

      setState(() {
        _codeSent = true;
      });
      _startCountdown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已发送，请查收')));
    } catch (e) {
      debugPrint('发送验证码失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. 验证并登录
  Future<void> _verifyAndLogin() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (code.isEmpty || code.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入完整的验证码')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 🌟 调用 Supabase 验证 OTP
      final AuthResponse res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.sms,
        token: code,
        phone: '+86$phone',
      );

      if (res.session != null) {
        // 登录成功！你可以跳转到主页 MainTabController
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录成功！')));
        // TODO: Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainTabController()));
      }
    } catch (e) {
      debugPrint('验证失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码错误或已过期')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '欢迎来到',
                style: TextStyle(fontSize: 24, color: Colors.black54),
              ),
              const Text(
                'G O A T',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                  letterSpacing: 4.0,
                ),
              ), // 你可以换成 GoatApp.marsGreen
              const SizedBox(height: 8),
              const Text(
                '记录训练，成为历史最佳。',
                style: TextStyle(fontSize: 14, color: Colors.black38),
              ),
              const SizedBox(height: 48),

              // 手机号输入框
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '请输入手机号',
                    prefixIcon: Icon(
                      Icons.phone_iphone_rounded,
                      color: Colors.black38,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 验证码输入框与发送按钮
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '短信验证码',
                          prefixIcon: Icon(
                            Icons.mark_email_read_rounded,
                            color: Colors.black38,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 获取验证码按钮
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          (_countdown > 0 && _countdown < 60) || _isLoading
                          ? null
                          : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1E3A8A,
                        ), // GoatApp.marsGreen
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        (_countdown > 0 && _countdown < 60)
                            ? '$_countdown s'
                            : '获取验证码',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyAndLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF1E3A8A,
                    ), // GoatApp.marsGreen
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '登 录',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4.0,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
