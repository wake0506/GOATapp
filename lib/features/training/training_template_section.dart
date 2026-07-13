import 'package:flutter/material.dart';

class TrainingTemplate {
  final String title;
  final String subtitle;
  final IconData icon;

  const TrainingTemplate({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class TrainingTemplateSection extends StatelessWidget {
  final ValueChanged<TrainingTemplate> onSelect;

  const TrainingTemplateSection({super.key, required this.onSelect});

  static const templates = <TrainingTemplate>[
    TrainingTemplate(
      title: '胸',
      subtitle: '推类训练与胸部刺激',
      icon: Icons.accessibility_new_rounded,
    ),
    TrainingTemplate(
      title: '背',
      subtitle: '拉类训练与背部控制',
      icon: Icons.fitness_center_rounded,
    ),
    TrainingTemplate(
      title: '腿',
      subtitle: '下肢力量与稳定性',
      icon: Icons.directions_run_rounded,
    ),
    TrainingTemplate(
      title: '肩',
      subtitle: '肩部力量与活动度',
      icon: Icons.arrow_upward_rounded,
    ),
    TrainingTemplate(
      title: '手臂',
      subtitle: '肱二头与肱三头训练',
      icon: Icons.front_hand_outlined,
    ),
    TrainingTemplate(
      title: '核心 / 全身',
      subtitle: '核心稳定与综合训练',
      icon: Icons.grid_view_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '分类模板',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      const Text(
        '选择部位后即可创建训练记录',
        style: TextStyle(color: Color(0xFF70757A), fontSize: 13),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: templates
                .map(
                  (template) => SizedBox(
                    width: cardWidth,
                    child: _TemplateCard(
                      template: template,
                      onTap: () => onSelect(template),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _TemplateCard extends StatelessWidget {
  final TrainingTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${template.title}训练模板',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x0D000000)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(template.icon, size: 20, color: const Color(0xFF008C8C)),
            const SizedBox(height: 12),
            Text(
              template.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              template.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF70757A),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
