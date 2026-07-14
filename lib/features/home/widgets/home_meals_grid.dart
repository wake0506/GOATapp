import 'package:flutter/material.dart';

import '../models/home_dashboard_view_model.dart';

class HomeMealsGrid extends StatelessWidget {
  const HomeMealsGrid({
    super.key,
    required this.meals,
    required this.onOpenMeal,
    required this.onAddMeal,
    required this.onVoiceMeal,
  });

  final List<HomeMealSummary> meals;
  final ValueChanged<String> onOpenMeal;
  final ValueChanged<String> onAddMeal;
  final ValueChanged<String> onVoiceMeal;

  @override
  Widget build(BuildContext context) => GridView.builder(
    key: const Key('home-meals-grid'),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: meals.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.18,
    ),
    itemBuilder: (context, index) {
      final meal = meals[index];
      return _HomeMealCard(
        meal: meal,
        onOpen: () => onOpenMeal(meal.mealType),
        onAdd: () => onAddMeal(meal.mealType),
        onVoice: () => onVoiceMeal(meal.mealType),
      );
    },
  );
}

class _HomeMealCard extends StatelessWidget {
  const _HomeMealCard({
    required this.meal,
    required this.onOpen,
    required this.onAdd,
    required this.onVoice,
  });

  final HomeMealSummary meal;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _mealIcon(meal.mealType),
                  size: 20,
                  color: _mealColor(meal.mealType),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meal.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF26302E),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _MealAction(
                  tooltip: '${meal.displayName}语音录入',
                  icon: Icons.mic_none_rounded,
                  onTap: onVoice,
                ),
                const SizedBox(width: 4),
                _MealAction(
                  tooltip: '${meal.displayName}添加食物',
                  icon: Icons.add,
                  onTap: onAdd,
                  accent: true,
                ),
              ],
            ),
            const Spacer(),
            Text.rich(
              TextSpan(
                text: meal.kcal.toInt().toString(),
                style: const TextStyle(
                  color: Color(0xFF202826),
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
                children: const [
                  TextSpan(
                    text: ' kcal',
                    style: TextStyle(
                      color: Color(0xFF66706E),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (meal.hasRecords)
              Text(
                meal.foodNames.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF818A89), fontSize: 10),
              )
            else
              const Text(
                '暂无记录',
                style: TextStyle(color: Color(0xFF9AA1A0), fontSize: 10),
              ),
            if (meal.hasRecords) ...[
              const SizedBox(height: 4),
              Text(
                '碳 ${meal.carbs.toInt()}g · 蛋 ${meal.protein.toInt()}g · 脂 ${meal.fat.toInt()}g',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF747D7C), fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _MealAction extends StatelessWidget {
  const _MealAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: accent ? Colors.white : const Color(0xFFF2F4F4),
          shape: BoxShape.circle,
          border: accent ? Border.all(color: const Color(0xFF83AAA4)) : null,
        ),
        child: Icon(
          icon,
          size: accent ? 22 : 17,
          color: accent ? const Color(0xFF008C8C) : const Color(0xFF51605D),
        ),
      ),
    ),
  );
}

IconData _mealIcon(String mealType) {
  switch (mealType) {
    case '早餐':
      return Icons.wb_sunny_outlined;
    case '午餐':
      return Icons.light_mode_outlined;
    case '晚餐':
      return Icons.wb_twilight_outlined;
    default:
      return Icons.nights_stay_outlined;
  }
}

Color _mealColor(String mealType) {
  switch (mealType) {
    case '早餐':
    case '午餐':
      return const Color(0xFFCC942B);
    case '晚餐':
      return const Color(0xFFC08A35);
    default:
      return const Color(0xFF506F87);
  }
}
