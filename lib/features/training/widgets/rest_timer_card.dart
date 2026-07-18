import 'package:flutter/material.dart';

class RestTimerCard extends StatelessWidget {
  const RestTimerCard({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.exerciseName,
    required this.nextSetLabel,
    required this.onStartNextSet,
    required this.onSkipRest,
    required this.onChangeDuration,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String exerciseName;
  final String nextSetLabel;
  final VoidCallback onStartNextSet;
  final VoidCallback onSkipRest;
  final VoidCallback onChangeDuration;

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds <= 0
        ? 0.0
        : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
    return Column(
      key: const Key('rest-timer-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1017211E),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                '休息中',
                style: TextStyle(
                  color: Color(0xFF008C8C),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 184,
                height: 184,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFFE8EEEC),
                        color: const Color(0xFF008C8C),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatSeconds(remainingSeconds),
                          style: const TextStyle(
                            color: Color(0xFF1F2725),
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Text(
                          '剩余休息',
                          style: TextStyle(
                            color: Color(0xFF8A9290),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '下一组',
                      style: TextStyle(color: Color(0xFF8A9290), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2725),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextSetLabel,
                      style: const TextStyle(
                        color: Color(0xFF68716F),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  key: const Key('rest-start-next-set'),
                  onPressed: onStartNextSet,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF008C8C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    '开始下一组',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  TextButton(
                    key: const Key('rest-skip'),
                    onPressed: onSkipRest,
                    child: const Text('跳过休息'),
                  ),
                  TextButton(
                    key: const Key('rest-duration-button'),
                    onPressed: onChangeDuration,
                    child: const Text('修改休息时间'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
