import 'json_value.dart';

class ConsumedRecord {
  final String id;
  final String name;
  final double p;
  final double c;
  final double f;
  final double kcal;
  final String mealType;
  final String date;
  final double amount;
  final String unit;

  ConsumedRecord({
    required this.id,
    required this.name,
    required this.p,
    required this.c,
    required this.f,
    required this.kcal,
    required this.mealType,
    required this.date,
    this.amount = 100.0,
    this.unit = 'g',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'p': p,
    'c': c,
    'f': f,
    'kcal': kcal,
    'mealType': mealType,
    'date': date,
    'amount': amount,
    'unit': unit,
  };

  factory ConsumedRecord.fromJson(Map<String, dynamic> json) => ConsumedRecord(
    id: stringValue(json['id']),
    name: stringValue(json['name'], '未命名食物'),
    p: doubleValue(json['p']),
    c: doubleValue(json['c']),
    f: doubleValue(json['f']),
    kcal: doubleValue(json['kcal']),
    mealType: stringValue(json['mealType'], '加餐'),
    date: stringValue(json['date']),
    amount: doubleValue(json['amount'], 100),
    unit: stringValue(json['unit'], 'g'),
  );
}
