import 'package:flutter/material.dart';

class HomeAiCard extends StatefulWidget {
  const HomeAiCard({
    super.key,
    required this.content,
    required this.isLoading,
    required this.onRefresh,
    required this.onClose,
  });

  final String content;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  State<HomeAiCard> createState() => _HomeAiCardState();
}

class _HomeAiCardState extends State<HomeAiCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final content = widget.content.trim().isEmpty
        ? '完成更多饮食记录后，这里会提供更有针对性的建议。'
        : widget.content.trim();
    return Container(
      key: const Key('home-ai-card'),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F2),
        border: Border.all(color: const Color(0xFFCFE9E0)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF008C8C),
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DeepSeek 饮食建议',
                  style: TextStyle(
                    color: Color(0xFF008C8C),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.isLoading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF008C8C),
                    ),
                  )
                else ...[
                  Text(
                    content,
                    maxLines: _expanded ? 5 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF52605D),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: widget.content.trim().isEmpty
                        ? widget.onRefresh
                        : () => setState(() => _expanded = !_expanded),
                    child: Text(
                      widget.content.trim().isEmpty
                          ? '查看建议  ›'
                          : _expanded
                          ? '收起  ›'
                          : '查看建议  ›',
                      style: const TextStyle(
                        color: Color(0xFF287A6B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '隐藏本次建议',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, size: 19),
            color: const Color(0xFF61726E),
          ),
        ],
      ),
    );
  }
}
