import 'package:flutter/material.dart';

import 'dashboard_data.dart';

class MealSummarySection extends StatelessWidget {
  final List<DashboardMealSummary> meals;
  final ValueChanged<String> onOpenMeal;
  final ValueChanged<String> onAddMeal;

  const MealSummarySection({
    super.key,
    required this.meals,
    required this.onOpenMeal,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日饮食',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...meals.map(
          (meal) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MealCard(meal: meal, onOpen: onOpenMeal, onAdd: onAddMeal),
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final DashboardMealSummary meal;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onAdd;

  const _MealCard({
    required this.meal,
    required this.onOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('dashboard-meal-${meal.mealType}'),
      container: true,
      label:
          '${meal.title}，${meal.isEmpty ? '暂无记录' : '${meal.calories.toStringAsFixed(0)} 千卡'}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => onOpen(meal.mealType),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            meal.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${meal.calories.toStringAsFixed(0)} kcal',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (meal.isEmpty)
                        const Text(
                          '暂无记录',
                          style: TextStyle(fontSize: 12, color: Colors.black38),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 3,
                          children: [
                            ...meal.foodNames.map(
                              (name) => Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            if (meal.moreCount > 0)
                              Text(
                                '另有 ${meal.moreCount} 项',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black38,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: '添加${meal.title}',
                  child: IconButton(
                    tooltip: '添加${meal.title}',
                    onPressed: () => onAdd(meal.mealType),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF008C8C),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
