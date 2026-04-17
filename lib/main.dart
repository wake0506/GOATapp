import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() => runApp(const GoatApp());

// ---------------------------------------------------------
// 1. 数据模型
// ---------------------------------------------------------
class FoodItem {
  String name;
  double protein; double carbs; double fat; double calories;
  String category; 

  FoodItem({required this.name, required this.protein, required this.carbs, required this.fat, required this.calories, this.category = '主食'});

  Map<String, dynamic> toJson() => {'name': name, 'protein': protein, 'carbs': carbs, 'fat': fat, 'calories': calories, 'category': category};
  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    name: json['name'], protein: json['protein'], carbs: json['carbs'], fat: json['fat'], calories: (json['calories'] ?? 0).toDouble(), category: json['category'] ?? '主食',
  );
}

class ConsumedRecord {
  final String id;
  final String name;
  final double p; final double c; final double f; final double kcal;
  final String mealType; 

  ConsumedRecord({required this.id, required this.name, required this.p, required this.c, required this.f, required this.kcal, required this.mealType});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'p': p, 'c': c, 'f': f, 'kcal': kcal, 'mealType': mealType};
  factory ConsumedRecord.fromJson(Map<String, dynamic> json) => ConsumedRecord(
    id: json['id'], name: json['name'], p: json['p'], c: json['c'], f: json['f'], kcal: (json['kcal'] ?? 0).toDouble(), mealType: json['mealType'] ?? '加餐',
  );
}

class GoatApp extends StatelessWidget {
  const GoatApp({super.key});
  
  static const TextStyle squareStyle = TextStyle(
    fontFamily: 'monospace',
    letterSpacing: 0.5,
    fontWeight: FontWeight.w600,
  );

  // 确认为你提供的马尔斯绿 (#008C8C)
  static const Color marsGreen = Color(0xFF008C8C); 

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FoodItem> foodDatabase = [];
  List<ConsumedRecord> consumedItems = [];
  double targetP = 150; double targetC = 200; double targetF = 60; double targetKcal = 2000;
  int todayWater = 0; double currentWeight = 0.0;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      targetP = prefs.getDouble('targetP') ?? 150;
      targetC = prefs.getDouble('targetC') ?? 200;
      targetF = prefs.getDouble('targetF') ?? 60;
      targetKcal = prefs.getDouble('targetKcal') ?? 2000;
      todayWater = prefs.getInt('todayWater') ?? 0;
      currentWeight = prefs.getDouble('currentWeight') ?? 0.0;
      
      // 键值统一使用 goat_database
      final String? foodsJson = prefs.getString('goat_database');
      if (foodsJson != null) {
        foodDatabase = List<FoodItem>.from(json.decode(foodsJson).map((x) => FoodItem.fromJson(x)));
      } else {
        // 如果本地没数据，则加载下面这个超级丰富的初始库
        foodDatabase = _getRichDefaultDatabase();
      }
      
      final String? consumedJson = prefs.getString('goat_consumed');
      if (consumedJson != null) consumedItems = List<ConsumedRecord>.from(json.decode(consumedJson).map((x) => ConsumedRecord.fromJson(x)));
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('targetP', targetP); prefs.setDouble('targetC', targetC);
    prefs.setDouble('targetF', targetF); prefs.setDouble('targetKcal', targetKcal);
    prefs.setInt('todayWater', todayWater); prefs.setDouble('currentWeight', currentWeight);
    prefs.setString('goat_database', json.encode(foodDatabase));
    prefs.setString('goat_consumed', json.encode(consumedItems));
  }

  @override
  Widget build(BuildContext context) {
    double totalKcal = consumedItems.fold(0, (sum, item) => sum + item.kcal);
    double totalP = consumedItems.fold(0, (sum, item) => sum + item.p);
    double totalC = consumedItems.fold(0, (sum, item) => sum + item.c);
    double totalF = consumedItems.fold(0, (sum, item) => sum + item.f);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F7), elevation: 0,
        title: const Text('G O A T', style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 6.0, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        children: [
          _buildDashboard(totalKcal, totalP, totalC, totalF),
          const SizedBox(height: 16),
          _buildWaterWeightRow(),
          const SizedBox(height: 16),
          _buildDietGrid(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // UI：仪表盘
  // ---------------------------------------------------------
  Widget _buildDashboard(double kcal, double p, double c, double f) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        const Text('ENERGY IN', style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('${kcal.toInt()}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: GoatApp.marsGreen)), 
          const Text(' / ', style: TextStyle(color: Colors.black12, fontSize: 20)),
          Text('${targetKcal.toInt()}', style: const TextStyle(color: Colors.black26, fontSize: 16)),
        ]),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _semiCircleWithLabel('PRO', p, targetP, GoatApp.marsGreen), 
          _semiCircleWithLabel('CHO', c, targetC, const Color(0xFF4DB6AC)), 
          _semiCircleWithLabel('FAT', f, targetF, const Color(0xFF80CBC4)), 
        ]),
      ]),
    );
  }

  Widget _semiCircleWithLabel(String label, double current, double target, Color color) {
    double progress = (target > 0 ? (current / target) : 0.0).clamp(0.0, 1.0);
    return Column(children: [
      SizedBox(width: 60, height: 30, child: CustomPaint(painter: SemiCirclePainter(progress: progress, color: color))),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black26)),
      Text('${current.toInt()}g', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GoatApp.marsGreen)), 
    ]);
  }

  // ---------------------------------------------------------
  // UI：饮食网格
  // ---------------------------------------------------------
  Widget _buildDietGrid() {
    return Column(children: [
      Row(children: [
        Expanded(child: _dietSmallBox('早餐', '早餐')),
        const SizedBox(width: 12),
        Expanded(child: _dietSmallBox('午餐', '午餐')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _dietSmallBox('晚餐', '晚餐')),
        const SizedBox(width: 12),
        Expanded(child: _dietSmallBox('日常补充', '加餐')),
      ]),
      const SizedBox(height: 12),
      _dietSmallBox('补剂打卡', '补剂'),
    ]);
  }

  Widget _dietSmallBox(String title, String type) {
    double mealKcal = consumedItems.where((i) => i.mealType == type).fold(0, (sum, i) => sum + i.kcal);
    return GestureDetector(
      onTap: () => _showMealDetailPopup(title, type),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('${mealKcal.toInt()} kcal', style: const TextStyle(fontSize: 12, color: GoatApp.marsGreen)), 
          ]),
          const Icon(Icons.add_circle_outline, color: GoatApp.marsGreen, size: 22), 
        ]),
      ),
    );
  }

  // ---------------------------------------------------------
  // 功能：弹出层与数据库
  // ---------------------------------------------------------
  void _showFoodPicker(BuildContext context, String mealType) {
    String selectedCategory = (mealType == '补剂') ? '补剂' : '主食';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        final filteredList = foodDatabase.where((f) => f.category == selectedCategory).toList();
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('录入 $mealType', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                TextButton.icon(
                  onPressed: () => _showAddCustomFoodDialog(setModalState),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('新增自定义'),
                  style: TextButton.styleFrom(foregroundColor: GoatApp.marsGreen),
                )
              ]),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: ['主食', '肉蛋奶', '蔬果', '饮品', '补剂'].map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat), selected: selectedCategory == cat,
                  onSelected: (val) => setModalState(() => selectedCategory = cat),
                  selectedColor: GoatApp.marsGreen,
                  labelStyle: TextStyle(color: selectedCategory == cat ? Colors.white : Colors.black38, fontSize: 12),
                ),
              )).toList()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredList.length,
                separatorBuilder: (context, i) => const Divider(color: Color(0xFFF5F5F5)),
                itemBuilder: (context, i) {
                  final f = filteredList[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text('P:${f.protein} C:${f.carbs} F:${f.fat}', style: const TextStyle(fontSize: 11, color: Colors.black26)),
                    trailing: const Icon(Icons.add_circle, color: GoatApp.marsGreen, size: 24),
                    onTap: () {
                      setState(() => consumedItems.add(ConsumedRecord(id: DateTime.now().toString(), name: f.name, p: f.protein, c: f.carbs, f: f.fat, kcal: f.calories, mealType: mealType)));
                      _saveData(); Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _showAddCustomFoodDialog(Function setModalState) {
    final nameCtrl = TextEditingController();
    final pCtrl = TextEditingController(); final cCtrl = TextEditingController();
    final fCtrl = TextEditingController(); final kCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增自定义食物', style: TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '食物名称')),
          Row(children: [
            Expanded(child: TextField(controller: kCtrl, decoration: const InputDecoration(labelText: '热量kcal'), keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: pCtrl, decoration: const InputDecoration(labelText: '蛋白g'), keyboardType: TextInputType.number)),
          ]),
          Row(children: [
            Expanded(child: TextField(controller: cCtrl, decoration: const InputDecoration(labelText: '碳水g'), keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: fCtrl, decoration: const InputDecoration(labelText: '脂肪g'), keyboardType: TextInputType.number)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.black54))),
          TextButton(onPressed: () {
            if (nameCtrl.text.isNotEmpty) {
              final newFood = FoodItem(
                name: nameCtrl.text, protein: double.tryParse(pCtrl.text) ?? 0, carbs: double.tryParse(cCtrl.text) ?? 0,
                fat: double.tryParse(fCtrl.text) ?? 0, calories: double.tryParse(kCtrl.text) ?? 0, category: '主食' 
              );
              setState(() => foodDatabase.add(newFood));
              _saveData(); setModalState(() {}); Navigator.pop(context);
            }
          }, child: const Text('保存', style: TextStyle(color: GoatApp.marsGreen))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 超丰富初始数据库 (30+ 常用项)
  // ---------------------------------------------------------
  List<FoodItem> _getRichDefaultDatabase() {
    return [
      // 主食类
      FoodItem(name: '白米饭(100g)', protein: 2.6, carbs: 28, fat: 0.3, calories: 116, category: '主食'),
      FoodItem(name: '糙米饭(100g)', protein: 2.7, carbs: 23, fat: 0.9, calories: 111, category: '主食'),
      FoodItem(name: '红薯(100g)', protein: 1.6, carbs: 20, fat: 0.1, calories: 86, category: '主食'),
      FoodItem(name: '燕麦片(100g干重)', protein: 12, carbs: 66, fat: 7, calories: 367, category: '主食'),
      FoodItem(name: '全麦面包(片)', protein: 4, carbs: 18, fat: 1, calories: 95, category: '主食'),
      FoodItem(name: '玉米(根)', protein: 4, carbs: 19, fat: 1.2, calories: 106, category: '主食'),
      FoodItem(name: '意面(100g干重)', protein: 13, carbs: 71, fat: 1.5, calories: 350, category: '主食'),
      
      // 肉蛋奶类
      FoodItem(name: '鸡胸肉(100g)', protein: 24, carbs: 0, fat: 1.9, calories: 115, category: '肉蛋奶'),
      FoodItem(name: '瘦牛肉(100g)', protein: 21, carbs: 0, fat: 6, calories: 140, category: '肉蛋奶'),
      FoodItem(name: '鸡蛋(个)', protein: 7, carbs: 0.5, fat: 5, calories: 75, category: '肉蛋奶'),
      FoodItem(name: '蛋清(个)', protein: 3.6, carbs: 0.2, fat: 0, calories: 17, category: '肉蛋奶'),
      FoodItem(name: '三文鱼(100g)', protein: 20, carbs: 0, fat: 13, calories: 208, category: '肉蛋奶'),
      FoodItem(name: '虾仁(100g)', protein: 18, carbs: 0, fat: 0.8, calories: 85, category: '肉蛋奶'),
      FoodItem(name: '希腊酸奶(100g)', protein: 10, carbs: 3.6, fat: 0, calories: 59, category: '肉蛋奶'),
      FoodItem(name: '纯牛奶(250ml)', protein: 8, carbs: 12, fat: 9, calories: 160, category: '肉蛋奶'),
      
      // 蔬果类
      FoodItem(name: '西蓝花(100g)', protein: 3, carbs: 5, fat: 0.2, calories: 34, category: '蔬果'),
      FoodItem(name: '菠菜(100g)', protein: 2, carbs: 2, fat: 0, calories: 23, category: '蔬果'),
      FoodItem(name: '番茄(个)', protein: 1, carbs: 4, fat: 0.2, calories: 18, category: '蔬果'),
      FoodItem(name: '香蕉(个)', protein: 1.1, carbs: 23, fat: 0.3, calories: 89, category: '蔬果'),
      FoodItem(name: '苹果(个)', protein: 0.3, carbs: 14, fat: 0.2, calories: 52, category: '蔬果'),
      FoodItem(name: '蓝莓(100g)', protein: 0.7, carbs: 14, fat: 0.3, calories: 57, category: '蔬果'),
      FoodItem(name: '牛油果(个)', protein: 2, carbs: 8, fat: 15, calories: 160, category: '蔬果'),
      
      // 饮品与补剂类
      FoodItem(name: '美式咖啡', protein: 0, carbs: 0, fat: 0, calories: 2, category: '饮品'),
      FoodItem(name: '黑茶/绿茶', protein: 0, carbs: 0, fat: 0, calories: 1, category: '饮品'),
      FoodItem(name: '蛋白粉(1勺)', protein: 25, carbs: 2, fat: 1.5, calories: 120, category: '补剂'),
      FoodItem(name: '肌酸(5g)', protein: 0, carbs: 0, fat: 0, calories: 0, category: '补剂'),
      FoodItem(name: '左旋肉碱', protein: 0, carbs: 0, fat: 0, calories: 0, category: '补剂'),
      FoodItem(name: '复合维生素', protein: 0, carbs: 0, fat: 0, calories: 0, category: '补剂'),
      FoodItem(name: '鱼油(粒)', protein: 0, carbs: 0, fat: 1, calories: 9, category: '补剂'),
      FoodItem(name: '坚果(28g)', protein: 6, carbs: 6, fat: 14, calories: 160, category: '补剂'),
    ];
  }

  // ---------------------------------------------------------
  // 其他原有的辅助 UI
  // ---------------------------------------------------------
  Widget _buildWaterWeightRow() {
    return Row(children: [
      _smallInfoCard('WATER', '$todayWater ml', Icons.water_drop, const Color(0xFF81D4FA), () { setState(() => todayWater += 250); _saveData(); }),
      const SizedBox(width: 12),
      _smallInfoCard('WEIGHT', currentWeight > 0 ? '$currentWeight kg' : '--', Icons.monitor_weight, Colors.blueGrey, () {}),
    ]);
  }

  Widget _smallInfoCard(String title, String val, IconData icon, Color col, VoidCallback onTap) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: col.withOpacity(0.4), size: 14), const SizedBox(width: 4), Text(title, style: const TextStyle(fontSize: 10, color: Colors.black26, letterSpacing: 1))]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GoatApp.marsGreen)),
          GestureDetector(onTap: onTap, child: const Icon(Icons.add_box, color: GoatApp.marsGreen, size: 24)),
        ]),
      ]),
    ));
  }

  void _showMealDetailPopup(String title, String type) {
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setPopupState) {
      final items = consumedItems.where((i) => i.mealType == type).toList();
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle, color: GoatApp.marsGreen), onPressed: () { Navigator.pop(context); _showFoodPicker(context, type); }),
        ]),
        content: SizedBox(width: double.maxFinite, child: items.isEmpty ? const Text('无记录', textAlign: TextAlign.center) : ListView.builder(
          shrinkWrap: true, itemCount: items.length, itemBuilder: (context, i) => ListTile(
            title: Text(items[i].name, style: const TextStyle(fontSize: 13)),
            trailing: Text('${items[i].kcal.toInt()} kcal', style: const TextStyle(color: GoatApp.marsGreen, fontWeight: FontWeight.bold)),
            onLongPress: () { setState(() => consumedItems.remove(items[i])); _saveData(); setPopupState(() {}); },
          ))),
      );
    }));
  }
}

class SemiCirclePainter extends CustomPainter {
  final double progress; final Color color;
  SemiCirclePainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()..color = const Color(0xFFF5F5F5)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    final paintProgress = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height); final radius = size.width / 2;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi, false, paintBase);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi * progress, false, paintProgress);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}