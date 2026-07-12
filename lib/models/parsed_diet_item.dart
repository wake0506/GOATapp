import 'json_value.dart';

class ParsedDietItem {
  String name;
  double amount;
  String unit;
  double kcal;
  double protein;
  double carbs;
  double fat;
  String mealType;
  double? confidence;

  ParsedDietItem({
    required this.name,
    required this.amount,
    required this.unit,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealType,
    this.confidence,
  });

  factory ParsedDietItem.fromJson(
    Map<String, dynamic> json, {
    String defaultMealType = '加餐',
  }) {
    final item = ParsedDietItem(
      name: stringValue(json['name']).trim(),
      amount: _nonNegative(json['amount'], 100),
      unit: stringValue(json['unit'], 'g').trim(),
      kcal: _nonNegative(json['kcal'] ?? json['calories']),
      protein: _nonNegative(json['protein'] ?? json['p']),
      carbs: _nonNegative(json['carbs'] ?? json['c']),
      fat: _nonNegative(json['fat'] ?? json['f']),
      mealType: stringValue(json['mealType'], defaultMealType),
      confidence: json['confidence'] == null
          ? null
          : _bounded(json['confidence']),
    );
    if (item.name.isEmpty) throw const FormatException('缺少食物名称');
    return item;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'mealType': mealType,
    if (confidence != null) 'confidence': confidence,
  };
}

double _nonNegative(Object? value, [double fallback = 0]) {
  return doubleValue(value, fallback).clamp(0, 100000).toDouble();
}

double _bounded(Object? value) {
  return doubleValue(value).clamp(0, 1).toDouble();
}
