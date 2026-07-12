import 'json_value.dart';

class FoodItem {
  String id;
  String name;
  double protein;
  double carbs;
  double fat;
  double calories;
  String category;
  String unit;
  double weightPerUnit;

  FoodItem({
    String? id,
    required this.name,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    this.category = '主食',
    this.unit = '',
    this.weightPerUnit = 0.0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'calories': calories,
    'category': category,
    'unit': unit,
    'weightPerUnit': weightPerUnit,
  };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: stringValue(json['id']),
    name: stringValue(json['name'], '未命名食物'),
    protein: doubleValue(json['protein']),
    carbs: doubleValue(json['carbs']),
    fat: doubleValue(json['fat']),
    calories: doubleValue(json['calories']),
    category: stringValue(json['category'], '主食'),
    unit: stringValue(json['unit']),
    weightPerUnit: doubleValue(json['weightPerUnit']),
  );
}
