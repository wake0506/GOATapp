import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/parsed_diet_item.dart';

abstract interface class NutritionAiService {
  Future<List<ParsedDietItem>> parseDietText(
    String text, {
    String defaultMealType = '加餐',
  });
}

class NutritionAiException implements Exception {
  final String message;

  const NutritionAiException(this.message);

  @override
  String toString() => message;
}

class DeepSeekNutritionAiService implements NutritionAiService {
  final http.Client client;
  final bool _ownsClient;
  final String apiKey;
  bool _isParsing = false;

  DeepSeekNutritionAiService({http.Client? client, required this.apiKey})
    : client = client ?? http.Client(),
      _ownsClient = client == null;

  bool get isParsing => _isParsing;

  void dispose() {
    if (_ownsClient) client.close();
  }

  @override
  Future<List<ParsedDietItem>> parseDietText(
    String text, {
    String defaultMealType = '加餐',
  }) async {
    final input = text.trim();
    if (input.isEmpty) throw const NutritionAiException('请输入或说出饮食内容');
    if (apiKey.trim().isEmpty) {
      throw const NutritionAiException('未配置 DEEPSEEK_API_KEY');
    }
    if (_isParsing) {
      throw const NutritionAiException('正在解析，请勿重复提交');
    }

    _isParsing = true;
    try {
      final response = await client
          .post(
            Uri.parse('https://api.deepseek.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': 'deepseek-chat',
              'temperature': 0.1,
              'messages': [
                {
                  'role': 'system',
                  'content': '你是严格的营养记录 JSON 解析器，只返回 JSON 数组。',
                },
                {
                  'role': 'user',
                  'content':
                      '''将以下饮食描述解析为 JSON 数组，不要 Markdown，不要解释。每项必须包含 name, amount, unit, kcal, protein, carbs, fat, mealType；mealType 只能是早餐、午餐、晚餐、加餐。用户描述：$input''',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NutritionAiException('AI 请求失败（HTTP ${response.statusCode}）');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final choices = body is Map && body['choices'] is List
          ? body['choices'] as List
          : const [];
      final firstChoice = choices.isNotEmpty && choices.first is Map
          ? Map<String, dynamic>.from(choices.first)
          : const <String, dynamic>{};
      final message = firstChoice['message'] is Map
          ? Map<String, dynamic>.from(firstChoice['message'])
          : const <String, dynamic>{};
      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        throw const NutritionAiException('AI 返回内容为空');
      }

      final decoded = jsonDecode(_stripMarkdownFence(content));
      final rawItems = decoded is List
          ? decoded
          : decoded is Map && decoded['items'] is List
          ? decoded['items']
          : const [];
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
      if (items.isEmpty) throw const NutritionAiException('AI 没有返回有效食物项目');
      return items;
    } on NutritionAiException {
      rethrow;
    } on FormatException {
      throw const NutritionAiException('AI 返回的 JSON 格式无效');
    } catch (error) {
      throw NutritionAiException('AI 解析失败：$error');
    } finally {
      _isParsing = false;
    }
  }

  String _stripMarkdownFence(String content) {
    final trimmed = content.trim();
    final match = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return match?.group(1)?.trim() ?? trimmed;
  }
}
