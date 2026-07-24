import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/training.dart';
import '../models/ai_coach_state.dart';
import '../models/ai_memory.dart';
import '../models/ai_suggestion.dart';
import '../repositories/ai_coach_local_repository.dart';
import '../services/ai_suggestion_service.dart';
import '../services/behavior_memory_service.dart';
import '../widgets/ai_suggestion_card.dart';

class AiProfilePage extends StatefulWidget {
  const AiProfilePage({
    super.key,
    required this.preferences,
    required this.namespace,
    required this.trainingSessions,
  });

  final SharedPreferences preferences;
  final String namespace;
  final List<TrainingSession> trainingSessions;

  @override
  State<AiProfilePage> createState() => _AiProfilePageState();
}

class _AiProfilePageState extends State<AiProfilePage> {
  late final AiCoachLocalRepository _repository;
  AiCoachState _state = const AiCoachState();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = AiCoachLocalRepository(
      preferences: widget.preferences,
      namespace: widget.namespace,
    );
    _load();
  }

  Future<void> _load() async {
    var state = _repository.load();
    final derived = const BehaviorMemoryService().derive(
      sessions: widget.trainingSessions,
    );
    if (derived.isNotEmpty) {
      state = await _repository.upsertDerived(derived);
    }
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  List<AiMemoryItem> get _visibleMemories => _state.memories
      .where((item) => item.status != AiMemoryStatus.archived)
      .toList();

  @override
  Widget build(BuildContext context) {
    final userProvided = _visibleMemories
        .where(
          (item) =>
              item.sourceType == AiMemorySourceType.userProvided &&
              item.status == AiMemoryStatus.active,
        )
        .toList();
    final derived = _visibleMemories
        .where(
          (item) =>
              item.sourceType == AiMemorySourceType.behaviorDerived &&
              item.status == AiMemoryStatus.active,
        )
        .toList();
    final pending = _visibleMemories
        .where((item) => item.status == AiMemoryStatus.pendingConfirmation)
        .toList();
    final activeSuggestions = _state.suggestions
        .where(
          (item) =>
              item.status != AiSuggestionStatus.rejected &&
              item.status != AiSuggestionStatus.dismissed,
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF202725),
        title: const Text(
          'AI 对我的了解',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            key: const Key('ai-profile-add'),
            tooltip: '告诉 GOAT 新信息',
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF008C8C)),
            )
          : ListView(
              key: const Key('ai-profile-page'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _introCard(),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('待我确认', '${pending.length} 条推测'),
                  const SizedBox(height: 10),
                  ...pending.map(_memoryCard),
                ],
                const SizedBox(height: 24),
                _sectionTitle('你告诉 GOAT 的', '可随时编辑或删除'),
                const SizedBox(height: 10),
                if (userProvided.isEmpty)
                  _emptyCard('还没有主动填写的信息', '添加训练目标、器械、偏好或明确限制。')
                else
                  ...userProvided.map(_memoryCard),
                const SizedBox(height: 24),
                _sectionTitle('从训练记录中观察到的', '只使用确定性记录'),
                const SizedBox(height: 10),
                if (derived.isEmpty)
                  _emptyCard('记录还不够多', '积累训练后，这里会展示频率、常用器械与常练部位。')
                else
                  ...derived.map(_memoryCard),
                if (activeSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('GOAT 建议', '采用后仍需验证并保存'),
                  const SizedBox(height: 10),
                  ...activeSuggestions.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AiSuggestionCard(
                        suggestion: item,
                        onStatusChanged: (status) =>
                            _changeSuggestionStatus(item, status),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const _PrivacyNote(),
              ],
            ),
    );
  }

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C17211E),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.psychology_alt_rounded,
              color: Color(0xFF008C8C),
              size: 25,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '由你掌控的个人教练记忆',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'GOAT 会区分你主动提供的信息、训练记录中的规律和待确认的推测。未经确认的推测不会进入正式上下文。',
          style: TextStyle(
            color: Color(0xFF69716F),
            fontSize: 13,
            height: 1.55,
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF909795), fontSize: 11),
      ),
    ],
  );

  Widget _emptyCard(String title, String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF858D8B),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _memoryCard(AiMemoryItem item) => Container(
    key: Key('ai-memory-${item.id}'),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: item.status == AiMemoryStatus.pendingConfirmation
          ? Border.all(color: const Color(0xFFCFE3DF))
          : null,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.category.label,
                style: const TextStyle(
                  color: Color(0xFF008C8C),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.value,
                style: const TextStyle(
                  color: Color(0xFF202725),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _sourceLabel(item.sourceType),
                style: const TextStyle(color: Color(0xFF909795), fontSize: 11),
              ),
              if (item.status == AiMemoryStatus.pendingConfirmation) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      key: Key('ai-memory-confirm-${item.id}'),
                      onPressed: () =>
                          _setStatus(item.id, AiMemoryStatus.active),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF008C8C),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('确认'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: Key('ai-memory-reject-${item.id}'),
                      onPressed: () =>
                          _setStatus(item.id, AiMemoryStatus.rejected),
                      child: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        IconButton(
          key: Key('ai-memory-menu-${item.id}'),
          tooltip: '更多操作',
          onPressed: () => _showMemoryActions(item),
          icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF89918F)),
        ),
      ],
    ),
  );

  Future<void> _showAddSheet() async {
    final result =
        await showModalBottomSheet<
          ({AiProfileCategory category, String value})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => const _AddMemorySheet(),
        );
    if (result == null) return;
    final state = await _repository.addUserProvided(
      category: result.category,
      value: result.value,
    );
    if (!mounted) return;
    setState(() => _state = state);
  }

  Future<void> _showMemoryActions(AiMemoryItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('为什么 GOAT 这么认为'),
                onTap: () => Navigator.pop(context, 'source'),
              ),
              if (item.sourceType == AiMemorySourceType.userProvided)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('编辑'),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              if (item.status == AiMemoryStatus.pendingConfirmation) ...[
                ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: const Text('确认'),
                  onTap: () => Navigator.pop(context, 'confirm'),
                ),
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: const Text('拒绝'),
                  onTap: () => Navigator.pop(context, 'reject'),
                ),
              ],
              if (item.sourceType != AiMemorySourceType.userProvided)
                ListTile(
                  leading: const Icon(Icons.report_gmailerrorred_rounded),
                  title: const Text('这不对'),
                  onTap: () => Navigator.pop(context, 'incorrect'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('删除'),
                textColor: const Color(0xFFC65353),
                iconColor: const Color(0xFFC65353),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'source':
        await _showEvidence(item);
      case 'edit':
        await _editMemory(item);
      case 'confirm':
        await _setStatus(item.id, AiMemoryStatus.active);
      case 'reject':
        await _setStatus(item.id, AiMemoryStatus.rejected);
      case 'incorrect':
        await _setStatus(item.id, AiMemoryStatus.incorrect);
      case 'delete':
        await _archiveMemory(item.id);
    }
  }

  Future<void> _showEvidence(AiMemoryItem item) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          key: const Key('ai-memory-evidence-sheet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '为什么这么说',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(item.value, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 20),
            const Text(
              '依据',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (item.sourceRefs.isEmpty)
              const Text('暂无可展示的来源记录')
            else
              for (final ref in item.sourceRefs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${ref.label}${_rangeLabel(ref)}',
                    style: const TextStyle(
                      color: Color(0xFF69716F),
                      height: 1.4,
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );

  Future<void> _editMemory(AiMemoryItem item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditMemoryDialog(
        title: '编辑${item.category.label}',
        initialValue: item.value,
      ),
    );
    if (result == null || result.isEmpty) return;
    final state = await _repository.editMemory(item.id, result);
    if (!mounted) return;
    setState(() => _state = state);
  }

  Future<void> _setStatus(String id, AiMemoryStatus status) async {
    final state = await _repository.setMemoryStatus(id, status);
    if (!mounted) return;
    setState(() => _state = state);
  }

  Future<void> _archiveMemory(String id) async {
    final state = await _repository.archiveMemory(id);
    if (!mounted) return;
    setState(() => _state = state);
  }

  Future<void> _changeSuggestionStatus(
    AiSuggestion suggestion,
    AiSuggestionStatus status,
  ) async {
    try {
      final updated = const AiSuggestionTransitionService().transition(
        suggestion,
        status,
      );
      var state = await _repository.saveSuggestion(updated);
      final decision = switch (status) {
        AiSuggestionStatus.accepted => SuggestionDecision.accepted,
        AiSuggestionStatus.modified => SuggestionDecision.modified,
        AiSuggestionStatus.rejected => SuggestionDecision.rejected,
        _ => SuggestionDecision.dismissed,
      };
      state = await _repository.recordFeedback(
        SuggestionFeedback(
          suggestionId: suggestion.id,
          decision: decision,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() => _state = state);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前建议状态已变化，请刷新后重试。')));
    }
  }

  String _rangeLabel(AiMemorySourceRef ref) {
    if (ref.dateRangeStart == null || ref.dateRangeEnd == null) return '';
    return '（${ref.dateRangeStart} 至 ${ref.dateRangeEnd}）';
  }

  String _sourceLabel(AiMemorySourceType source) => switch (source) {
    AiMemorySourceType.userProvided => '你告诉 GOAT 的',
    AiMemorySourceType.behaviorDerived => '从训练记录中观察到的',
    AiMemorySourceType.aiInferred => '待确认的推测',
  };
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3F1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, color: Color(0xFF008C8C), size: 19),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Stage 3 V1 仅保存在当前本地账号命名空间。跨设备同步将在后端契约确认后另行接入。',
            style: TextStyle(
              color: Color(0xFF5D6A67),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddMemorySheet extends StatefulWidget {
  const _AddMemorySheet();

  @override
  State<_AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<_AddMemorySheet> {
  final TextEditingController _controller = TextEditingController();
  AiProfileCategory _category = AiProfileCategory.trainingGoal;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '告诉 GOAT',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<AiProfileCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '信息类别'),
              items: AiProfileCategory.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('ai-profile-value-input'),
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '例如：我更喜欢哑铃训练',
                filled: true,
                fillColor: Color(0xFFF4F5F7),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('ai-profile-save'),
                onPressed: () {
                  final value = _controller.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(context, (category: _category, value: value));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C8C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMemoryDialog extends StatefulWidget {
  const _EditMemoryDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_EditMemoryDialog> createState() => _EditMemoryDialogState();
}

class _EditMemoryDialogState extends State<_EditMemoryDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(widget.title),
      content: TextField(controller: _controller, autofocus: true, maxLines: 3),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
