import 'package:flutter/material.dart';

class AiTipCard extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onRefresh;

  const AiTipCard({
    super.key,
    required this.text,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x18008C8C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF008C8C), size: 17),
          const SizedBox(width: 8),
          const Text(
            '今日建议',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF008C8C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLoading ? '正在更新…' : text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          IconButton(
            tooltip: '刷新今日建议',
            onPressed: isLoading ? null : onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
