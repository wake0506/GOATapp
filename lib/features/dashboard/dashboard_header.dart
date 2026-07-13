import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  final String businessDate;
  final bool isToday;
  final VoidCallback onOpenAssistant;

  const DashboardHeader({
    super.key,
    required this.businessDate,
    required this.isToday,
    required this.onOpenAssistant,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF4F5F7),
      elevation: 0,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'G O A T',
            style: TextStyle(
              fontWeight: FontWeight.w200,
              letterSpacing: 4,
              fontSize: 18,
            ),
          ),
          Text(
            isToday ? '今日状态' : businessDate,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
      actions: [
        Semantics(
          button: true,
          label: '打开 AI 助手',
          child: IconButton(
            tooltip: '打开 AI 助手',
            onPressed: onOpenAssistant,
            icon: const Icon(
              Icons.auto_awesome,
              color: const Color(0xFF008C8C),
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
