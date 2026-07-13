import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parsed_diet_item.dart';
import 'nutrition_ai_service.dart';

/// Production AI adapter. The provider credential is held only by the Edge
/// Function; the client sends the user's text and receives validated items.
class SupabaseNutritionAiService implements NutritionAiService {
  final SupabaseClient client;
  bool _isParsing = false;

  SupabaseNutritionAiService({required this.client});

  bool get isParsing => _isParsing;

  @override
  Future<List<ParsedDietItem>> parseDietText(
    String text, {
    String defaultMealType = '加餐',
  }) async {
    final input = text.trim();
    if (input.isEmpty) throw const NutritionAiException('请输入或说出饮食内容');
    if (_isParsing) {
      throw const NutritionAiException('正在解析，请勿重复提交');
    }

    _isParsing = true;
    try {
      final response = await client.functions
          .invoke(
            'nutrition-ai',
            body: {
              'text': input,
              'defaultMealType': defaultMealType,
              'clientRequestId':
                  'nutrition-${DateTime.now().microsecondsSinceEpoch}',
            },
          )
          .timeout(const Duration(seconds: 20));

      final data = response.data;
      if (data is! Map) {
        throw const NutritionAiException('AI 返回内容无效');
      }
      if (data['code'] != null) {
        throw NutritionAiException(data['message']?.toString() ?? 'AI 请求失败');
      }
      final rawItems = data['items'];
      if (rawItems is! List) {
        throw const NutritionAiException('AI 没有返回有效食物项目');
      }

      final items = <ParsedDietItem>[];
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        try {
          items.add(
            ParsedDietItem.fromJson(
              Map<String, dynamic>.from(raw),
              defaultMealType: defaultMealType,
            ),
          );
        } on FormatException {
          continue;
        }
      }
      if (items.isEmpty) {
        throw const NutritionAiException('AI 没有返回有效食物项目');
      }
      return items;
    } on NutritionAiException {
      rethrow;
    } on FunctionException catch (error) {
      throw NutritionAiException(error.reasonPhrase ?? 'AI 请求失败');
    } on TimeoutException {
      throw const NutritionAiException('AI 请求超时，请稍后重试');
    } catch (error) {
      throw NutritionAiException('AI 解析失败：$error');
    } finally {
      _isParsing = false;
    }
  }
}
