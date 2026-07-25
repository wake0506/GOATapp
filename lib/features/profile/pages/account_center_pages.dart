import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../ai_coach/models/ai_coach_state.dart';
import '../../ai_coach/models/ai_suggestion.dart';
import '../../analytics/models/weight_trend.dart';
import '../../analytics/widgets/weight_trend_summary.dart';
import '../../../widgets/goat_page_header.dart';
import '../services/account_deletion_service.dart';

const _marsGreen = Color(0xFF008C8C);
const _background = Color(0xFFF4F5F7);
const _charcoal = Color(0xFF202725);
const _muted = Color(0xFF747D7A);

class SuggestionHistoryPage extends StatefulWidget {
  const SuggestionHistoryPage({super.key, required this.stateLoader});

  final AiCoachState Function() stateLoader;

  @override
  State<SuggestionHistoryPage> createState() => _SuggestionHistoryPageState();
}

class _SuggestionHistoryPageState extends State<SuggestionHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  late AiCoachState _state;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _state = widget.stateLoader();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('suggestion-history-page'),
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      elevation: 0,
      title: const GoatPageHeader(title: 'GOAT 建 议 记 录'),
      bottom: TabBar(
        controller: _controller,
        labelColor: _marsGreen,
        indicatorColor: _marsGreen,
        unselectedLabelColor: _muted,
        tabs: const [
          Tab(text: '待处理'),
          Tab(text: '已采用'),
          Tab(text: '已忽略'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _controller,
      children: [
        _SuggestionList(
          suggestions: _whereStatuses(const {
            AiSuggestionStatus.proposed,
            AiSuggestionStatus.applyFailed,
          }),
          emptyText: '目前没有待处理建议',
          onTap: _showDetails,
        ),
        _SuggestionList(
          suggestions: _whereStatuses(const {
            AiSuggestionStatus.accepted,
            AiSuggestionStatus.modified,
            AiSuggestionStatus.applied,
          }),
          emptyText: '尚未采用建议',
          onTap: _showDetails,
        ),
        _SuggestionList(
          suggestions: _whereStatuses(const {
            AiSuggestionStatus.rejected,
            AiSuggestionStatus.dismissed,
          }),
          emptyText: '没有已忽略的建议',
          onTap: _showDetails,
        ),
      ],
    ),
  );

  List<AiSuggestion> _whereStatuses(Set<AiSuggestionStatus> statuses) {
    final values =
        _state.suggestions
            .where((item) => statuses.contains(item.status))
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return values;
  }

  void _showDetails(AiSuggestion suggestion) {
    final feedback =
        _state.feedback
            .where((item) => item.suggestionId == suggestion.id)
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(label: suggestionStatusLabel(suggestion.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${suggestionTypeLabel(suggestion.type)} · ${_formatDate(suggestion.createdAt)}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            const _DetailTitle('建议内容'),
            Text(
              suggestion.summary.isEmpty ? '暂无补充说明' : suggestion.summary,
              style: const TextStyle(height: 1.55),
            ),
            const SizedBox(height: 18),
            const _DetailTitle('依据'),
            Text(
              suggestion.evidenceRefs.isEmpty
                  ? '没有可展示的个人记录依据。'
                  : '使用了 ${suggestion.evidenceRefs.length} 条训练或趋势数据依据。',
              style: const TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 5),
            Text(
              suggestion.knowledgeRefs.isEmpty
                  ? '未引用额外知识条目。'
                  : '参考了 ${suggestion.knowledgeRefs.length} 条已审核知识。',
              style: const TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            const _DetailTitle('执行状态'),
            Text(
              _applicationDescription(suggestion),
              style: const TextStyle(color: _muted, height: 1.5),
            ),
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _DetailTitle('你的反馈'),
              Text(
                suggestionDecisionLabel(feedback.first.decision),
                style: const TextStyle(color: _muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _applicationDescription(AiSuggestion suggestion) {
    if (suggestion.status == AiSuggestionStatus.applied) {
      return '已通过确认、规则校验与本地持久化。';
    }
    if (suggestion.status == AiSuggestionStatus.applyFailed) {
      return suggestion.failureMessage?.trim().isNotEmpty == true
          ? '应用失败：${suggestion.failureMessage}'
          : '应用失败，原训练数据未被修改。';
    }
    if (suggestion.status == AiSuggestionStatus.accepted ||
        suggestion.status == AiSuggestionStatus.modified) {
      return '你已接受，但尚未完成应用；原训练数据保持不变。';
    }
    if (suggestion.status == AiSuggestionStatus.rejected ||
        suggestion.status == AiSuggestionStatus.dismissed) {
      return '该建议未应用，原训练数据保持不变。';
    }
    return '等待你决定。未经确认不会修改训练计划。';
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.emptyText,
    required this.onTap,
  });

  final List<AiSuggestion> suggestions;
  final String emptyText;
  final ValueChanged<AiSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(emptyText, style: const TextStyle(color: _muted)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      itemCount: suggestions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: Key('suggestion-history-${suggestion.id}'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => onTap(suggestion),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      color: Color(0xFF4D6BFE),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${suggestionTypeLabel(suggestion.type)} · ${_formatDate(suggestion.createdAt)}',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(label: suggestionStatusLabel(suggestion.status)),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFFB1B8B6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4F3),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF5E6966),
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DetailTitle extends StatelessWidget {
  const _DetailTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

class AiKnowledgeExplanationPage extends StatelessWidget {
  const AiKnowledgeExplanationPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('ai-knowledge-explanation-page'),
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const GoatPageHeader(title: 'GOAT 如 何 给 出 建 议'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: const [
        _ExplanationIntro(),
        SizedBox(height: 12),
        _ExplanationStep(
          number: '01',
          title: '读取与你有关的必要信息',
          body: '只按当前任务使用训练记录、趋势数据，以及你主动填写或确认的偏好。',
        ),
        _ExplanationStep(
          number: '02',
          title: '先运行确定性分析',
          body: '周复盘、有效组、趋势体重、休息建议等结果由明确规则计算，不交给语言模型猜测。',
        ),
        _ExplanationStep(
          number: '03',
          title: '检索已审核知识',
          body: '建议只引用当前知识库中已审核且与任务匹配的条目，并保留依据关系。',
        ),
        _ExplanationStep(
          number: '04',
          title: '由 AI 组织解释',
          body: 'AI 负责把结构化结果转成容易理解的说明；数据不足时应明确降级，而不是编造结论。',
        ),
        _ExplanationStep(
          number: '05',
          title: '由你决定是否应用',
          body: 'GOAT 不会未经确认修改训练计划。只有确认、规则校验与保存都成功后，建议才会标记为已应用。',
        ),
      ],
    ),
  );
}

class _ExplanationIntro extends StatelessWidget {
  const _ExplanationIntro();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.fact_check_outlined, color: Color(0xFF4D6BFE)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            '建议来自真实记录、确定性分析与受控知识，而不是替你做决定。',
            style: TextStyle(
              color: _charcoal,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExplanationStep extends StatelessWidget {
  const _ExplanationStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: _marsGreen,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class RecordsHubPage extends StatelessWidget {
  const RecordsHubPage({
    super.key,
    required this.onOpenWeight,
    required this.onOpenTraining,
    required this.onOpenWeeklyReview,
    required this.onOpenDiet,
    required this.onOpenWater,
  });

  final Future<void> Function() onOpenWeight;
  final Future<void> Function() onOpenTraining;
  final Future<void> Function() onOpenWeeklyReview;
  final Future<void> Function() onOpenDiet;
  final Future<void> Function() onOpenWater;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('records-hub-page'),
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const GoatPageHeader(title: '健 康 与 记 录'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _HubCard(
          children: [
            _HubRow(
              icon: Icons.monitor_weight_outlined,
              title: '体重记录',
              onTap: onOpenWeight,
            ),
            _HubRow(
              icon: Icons.history_outlined,
              title: '训练历史',
              onTap: onOpenTraining,
            ),
            _HubRow(
              icon: Icons.insights_outlined,
              title: '周复盘',
              onTap: onOpenWeeklyReview,
            ),
            _HubRow(
              icon: Icons.restaurant_outlined,
              title: '饮食记录',
              onTap: onOpenDiet,
            ),
            _HubRow(
              icon: Icons.water_drop_outlined,
              title: '饮水记录',
              onTap: onOpenWater,
            ),
          ],
        ),
      ],
    ),
  );
}

class WeightHistoryPage extends StatelessWidget {
  const WeightHistoryPage({
    super.key,
    required this.trend,
    required this.records,
    required this.onAddWeight,
  });

  final WeightTrend trend;
  final List<WeightRecord> records;
  final Future<void> Function() onAddWeight;

  @override
  Widget build(BuildContext context) {
    final ordered = [...records]
      ..sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
    return Scaffold(
      key: const Key('weight-history-page'),
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const GoatPageHeader(title: '体 重 记 录'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: WeightTrendSummary(trend: trend),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('weight-history-add'),
            onPressed: () => onAddWeight(),
            style: FilledButton.styleFrom(
              backgroundColor: _marsGreen,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('记录体重'),
          ),
          const SizedBox(height: 16),
          const Text(
            '历史读数',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (ordered.isEmpty)
            const _EmptyCard(text: '还没有体重记录')
          else
            _HubCard(
              children: [
                for (final record in ordered) _WeightRow(record: record),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.record});

  final WeightRecord record;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${record.recordedAt.year}.${record.recordedAt.month.toString().padLeft(2, '0')}.${record.recordedAt.day.toString().padLeft(2, '0')}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        Text(
          '${record.weightKg.toStringAsFixed(2)} kg',
          style: const TextStyle(color: _charcoal, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class DataPrivacyPage extends StatefulWidget {
  const DataPrivacyPage({
    super.key,
    required this.isLoggedIn,
    required this.onExportCloud,
    required this.onExportLocal,
    required this.onOpenAiProfile,
    required this.onDeleteAccount,
  });

  final bool isLoggedIn;
  final Future<String> Function() onExportCloud;
  final Future<String> Function() onExportLocal;
  final Future<void> Function() onOpenAiProfile;
  final Future<void> Function(String confirmation) onDeleteAccount;

  @override
  State<DataPrivacyPage> createState() => _DataPrivacyPageState();
}

class _DataPrivacyPageState extends State<DataPrivacyPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('data-privacy-page'),
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const GoatPageHeader(title: '数 据 与 隐 私'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (widget.isLoggedIn)
          _HubCard(
            children: [
              _HubRow(
                key: const Key('privacy-cloud-export'),
                icon: Icons.cloud_download_outlined,
                title: '导出我的云端数据',
                subtitle: '获取账号在云端保存的个人数据',
                enabled: !_busy,
                onTap: _exportCloud,
              ),
            ],
          ),
        if (widget.isLoggedIn) const SizedBox(height: 12),
        _HubCard(
          children: [
            _HubRow(
              key: const Key('privacy-local-export'),
              icon: Icons.phone_android_outlined,
              title: '导出本设备数据',
              subtitle: '训练方案、AI 信息与当前本地记录',
              enabled: !_busy,
              onTap: _exportLocal,
            ),
            _HubRow(
              key: const Key('privacy-ai-data'),
              icon: Icons.psychology_alt_outlined,
              title: 'AI 数据说明',
              subtitle: '了解用户输入、行为统计与待确认推测',
              onTap: _showAiData,
            ),
            _HubRow(
              key: const Key('privacy-local-data'),
              icon: Icons.storage_outlined,
              title: '本地数据说明',
              subtitle: '了解本设备保存与跨设备同步范围',
              onTap: _showLocalData,
            ),
          ],
        ),
        if (!widget.isLoggedIn) ...[
          const SizedBox(height: 12),
          const _InfoCard(
            icon: Icons.cloud_off_outlined,
            text: '当前为本地使用。登录后才能导出云端账户数据或删除云端账号。',
          ),
        ],
        if (widget.isLoggedIn) ...[
          const SizedBox(height: 22),
          const Text(
            '危险操作',
            style: TextStyle(
              color: Color(0xFFB23A3A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: const Color(0xFFFFF6F5),
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              key: const Key('privacy-delete-account'),
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Color(0xFFBE3F3F),
              ),
              title: const Text(
                '删除账户',
                style: TextStyle(
                  color: Color(0xFF9F3030),
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text('永久删除云端账号与相关数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : _openDelete,
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _exportCloud() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出云端数据'),
        content: const Text(
          '云端导出包含当前账号已同步的个人配置、饮食、运动、体重、饮水和训练记录。\n\n'
          '仅保存在本设备的 AI 信息、训练方案和局部训练设置不包含在此导出中。',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _marsGreen),
            child: const Text('导出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runExport(widget.onExportCloud);
  }

  Future<void> _exportLocal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出本设备数据'),
        content: const Text(
          '将生成 JSON 文件，只包含当前使用空间中的本地记录、训练方案和 AI 教练数据。'
          '不会包含 API Key、登录令牌、调试日志或公共知识库。',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _marsGreen),
            child: const Text('导出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runExport(widget.onExportLocal);
  }

  Future<void> _runExport(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final location = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出完成：$location')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAiData() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _InfoSheet(
        title: 'AI 数据说明',
        paragraphs: const [
          'GOAT 会在本设备保存你主动填写的训练目标、器械、偏好和限制。',
          '由训练记录得到的频率或常用器械属于行为统计；AI 推测的信息必须由你确认后才能用于个性化上下文。',
          '当前 AI Memory 与建议记录以本地保存为主，尚未提供完整跨设备同步。',
        ],
        actionLabel: '管理 AI 对我的了解',
        onAction: () {
          Navigator.pop(context);
          widget.onOpenAiProfile();
        },
      ),
    );
  }

  void _showLocalData() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _InfoSheet(
        title: '本地数据说明',
        paragraphs: [
          '部分训练方案、AI 个人档案与高级训练状态目前保存在本设备。',
          '这些数据不会自动出现在云端账户导出中。更换设备前可使用“导出本设备数据”保留一份 JSON 文件。',
          '跨设备同步仍在逐步完善。',
        ],
      ),
    );
  }

  Future<void> _openDelete() async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            DeleteAccountPage(onDeleteAccount: widget.onDeleteAccount),
      ),
    );
    if (deleted == true && mounted) {
      Navigator.pop(context);
    }
  }
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.onDeleteAccount});

  final Future<void> Function(String confirmation) onDeleteAccount;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      _controller.text == AccountDeletionService.confirmationPhrase;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('delete-account-page'),
    backgroundColor: _background,
    appBar: AppBar(backgroundColor: _background, title: const Text('删除账户')),
    body: SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB93636)),
                SizedBox(height: 12),
                Text(
                  '此操作不可撤销',
                  style: TextStyle(
                    color: Color(0xFF9F3030),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '账号以及云端保存的个人配置、饮食、运动、体重、饮水与训练记录将被永久删除。'
                  '远端删除成功后，本设备当前账号空间也会被清理并退出登录。',
                  style: TextStyle(color: Color(0xFF704747), height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('请输入确认短语', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          const SelectableText(
            AccountDeletionService.confirmationPhrase,
            style: TextStyle(
              color: Color(0xFF9F3030),
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('delete-account-confirmation'),
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('delete-account-submit'),
            onPressed: !_matches || _busy ? null : _confirmDelete,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB93636),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('永久删除我的账户'),
          ),
        ],
      ),
    ),
  );

  Future<void> _confirmDelete() async {
    final finalConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('最后确认'),
        content: const Text('确认永久删除当前账户？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('delete-account-final-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB93636),
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (finalConfirmation != true) return;
    setState(() => _busy = true);
    try {
      await widget.onDeleteAccount(_controller.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '删除失败：$error';
        });
      }
    }
  }
}

class AboutGoatPage extends StatefulWidget {
  const AboutGoatPage({
    super.key,
    required this.onOpenPrivacy,
    required this.onOpenLicenses,
  });

  final Future<void> Function() onOpenPrivacy;
  final Future<void> Function() onOpenLicenses;

  @override
  State<AboutGoatPage> createState() => _AboutGoatPageState();
}

class _AboutGoatPageState extends State<AboutGoatPage> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('about-goat-page'),
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const GoatPageHeader(title: '关 于 GOAT'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _marsGreen,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'G O A T',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 6,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '记录训练、饮食与身体趋势，让可验证的数据成为长期进步的基础。',
                style: TextStyle(
                  color: Color(0xFFDFF3F1),
                  height: 1.55,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            return _HubCard(
              children: [
                _StaticHubRow(
                  title: '版本',
                  value: info == null ? '读取中' : info.version,
                ),
                _StaticHubRow(
                  title: 'Build',
                  value: info == null ? '读取中' : info.buildNumber,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _HubCard(
          children: [
            _HubRow(
              icon: Icons.shield_outlined,
              title: '隐私与数据',
              onTap: widget.onOpenPrivacy,
            ),
            _HubRow(
              icon: Icons.article_outlined,
              title: '开源许可',
              onTap: widget.onOpenLicenses,
            ),
          ],
        ),
      ],
    ),
  );
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            const Divider(height: 1, indent: 54, endIndent: 14),
        ],
      ],
    ),
  );
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final FutureOr<void> Function() onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
    minTileHeight: 56,
    leading: Icon(icon, color: _marsGreen, size: 21),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: const TextStyle(color: _muted, fontSize: 11)),
    trailing: const Icon(
      Icons.chevron_right,
      size: 18,
      color: Color(0xFFB1B8B6),
    ),
    onTap: enabled ? () => onTap() : null,
  );
}

class _StaticHubRow extends StatelessWidget {
  const _StaticHubRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Expanded(child: Text(title)),
        Text(value, style: const TextStyle(color: _muted)),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _muted, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _muted, height: 1.5, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Center(
      child: Text(text, style: const TextStyle(color: _muted)),
    ),
  );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.title,
    required this.paragraphs,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<String> paragraphs;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                paragraph,
                style: const TextStyle(color: _muted, height: 1.55),
              ),
            ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(backgroundColor: _marsGreen),
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

String suggestionStatusLabel(AiSuggestionStatus status) => switch (status) {
  AiSuggestionStatus.proposed => '待处理',
  AiSuggestionStatus.accepted => '已接受',
  AiSuggestionStatus.modified => '已调整',
  AiSuggestionStatus.rejected => '已拒绝',
  AiSuggestionStatus.dismissed => '已忽略',
  AiSuggestionStatus.applied => '已应用',
  AiSuggestionStatus.applyFailed => '应用失败',
};

String suggestionTypeLabel(AiSuggestionType type) => switch (type) {
  AiSuggestionType.training => '训练',
  AiSuggestionType.progression => '进阶',
  AiSuggestionType.rest => '休息',
  AiSuggestionType.exercise => '动作',
  AiSuggestionType.nutrition => '营养',
  AiSuggestionType.profile => '档案',
  AiSuggestionType.memory => 'AI 信息',
};

String suggestionDecisionLabel(SuggestionDecision decision) =>
    switch (decision) {
      SuggestionDecision.accepted => '已接受',
      SuggestionDecision.modified => '调整后接受',
      SuggestionDecision.rejected => '已拒绝',
      SuggestionDecision.dismissed => '已忽略',
    };

String _formatDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
