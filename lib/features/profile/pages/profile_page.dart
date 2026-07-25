import 'dart:async';

import 'package:flutter/material.dart';

import '../../ai_coach/models/ai_memory.dart';
import '../models/profile_summary.dart';

const _marsGreen = Color(0xFF008C8C);
const _background = Color(0xFFF4F5F7);
const _charcoal = Color(0xFF202725);
const _muted = Color(0xFF747D7A);

enum ProfileActionId {
  editProfile,
  trainingHistorySummary,
  weeklyReviewSummary,
  trendWeightSummary,
  trainingGoal,
  trainingExperience,
  equipment,
  trainingPreferences,
  coachingStyle,
  trainingPlans,
  aiProfile,
  suggestionHistory,
  knowledgeExplanation,
  weightHistory,
  trainingHistory,
  weeklyReview,
  allRecords,
  dataPrivacy,
  about,
  licenses,
  login,
  logout,
}

typedef ProfileValueSaver =
    Future<void> Function(AiProfileCategory category, String? value);

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.identity,
    required this.basicData,
    required this.summaryLoader,
    required this.onSaveBasic,
    required this.onSaveProfileValue,
    required this.equipmentOptions,
    required this.onOpenTrainingHistory,
    required this.onOpenWeeklyReview,
    required this.onOpenWeightHistory,
    required this.onManageTrainingPlans,
    required this.onOpenAiProfile,
    required this.onOpenSuggestionHistory,
    required this.onOpenKnowledgeExplanation,
    required this.onOpenAllRecords,
    required this.onOpenDataPrivacy,
    required this.onOpenAbout,
    required this.onOpenLicenses,
    required this.onLogin,
    required this.onLogout,
  });

  final ProfileIdentity identity;
  final ProfileBasicData basicData;
  final Future<ProfileSummary> Function() summaryLoader;
  final Future<void> Function(ProfileBasicUpdate update) onSaveBasic;
  final ProfileValueSaver onSaveProfileValue;
  final List<String> equipmentOptions;
  final Future<void> Function() onOpenTrainingHistory;
  final Future<void> Function() onOpenWeeklyReview;
  final Future<void> Function() onOpenWeightHistory;
  final Future<void> Function() onManageTrainingPlans;
  final Future<void> Function() onOpenAiProfile;
  final Future<void> Function() onOpenSuggestionHistory;
  final Future<void> Function() onOpenKnowledgeExplanation;
  final Future<void> Function() onOpenAllRecords;
  final Future<void> Function() onOpenDataPrivacy;
  final Future<void> Function() onOpenAbout;
  final Future<void> Function() onOpenLicenses;
  final Future<void> Function() onLogin;
  final Future<void> Function() onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<ProfileSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.summaryLoader();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity.email != widget.identity.email ||
        oldWidget.identity.displayName != widget.identity.displayName ||
        oldWidget.basicData.currentWeightKg !=
            widget.basicData.currentWeightKg) {
      _reload();
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _summary = widget.summaryLoader();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('profile-account-center'),
    backgroundColor: _background,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => FutureBuilder<ProfileSummary>(
          future: _summary,
          builder: (context, snapshot) {
            final summary = snapshot.data;
            return RefreshIndicator(
              color: _marsGreen,
              onRefresh: () async {
                final next = widget.summaryLoader();
                setState(() => _summary = next);
                await next;
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth >= 720 ? 24 : 16,
                  12,
                  constraints.maxWidth >= 720 ? 24 : 16,
                  32,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '个 人 主 页',
                            style: TextStyle(
                              color: _charcoal,
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ProfileHeader(
                            identity: summary?.identity ?? widget.identity,
                            trainingGoal: summary?.trainingGoal,
                            weeklyTrainingDays: summary?.weeklyTrainingDays,
                            onEdit: () => _openEditProfile(
                              summary?.identity ?? widget.identity,
                            ),
                            onLogin: () => _run(widget.onLogin),
                          ),
                          const SizedBox(height: 12),
                          _ProgressSummaryCard(
                            summary: summary,
                            loading:
                                snapshot.connectionState ==
                                ConnectionState.waiting,
                            onTraining: () =>
                                _run(widget.onOpenTrainingHistory),
                            onWeekly: () => _run(widget.onOpenWeeklyReview),
                            onWeight: () => _run(widget.onOpenWeightHistory),
                          ),
                          const SizedBox(height: 18),
                          _SectionTitle(title: '目标与训练档案'),
                          _SectionCard(
                            children: [
                              _ActionRow(
                                id: ProfileActionId.trainingGoal,
                                icon: Icons.flag_outlined,
                                title: '训练目标',
                                value: summary?.trainingGoal ?? '未设置',
                                onTap: () => _openSingleChoice(
                                  title: '训练目标',
                                  category: AiProfileCategory.trainingGoal,
                                  current: summary?.trainingGoal,
                                  options: const [
                                    '增肌',
                                    '力量提升',
                                    '减脂',
                                    '保持健康',
                                    '综合训练',
                                  ],
                                ),
                              ),
                              _ActionRow(
                                id: ProfileActionId.trainingExperience,
                                icon: Icons.stairs_outlined,
                                title: '训练经验',
                                value: summary?.trainingExperience ?? '未设置',
                                onTap: () => _openSingleChoice(
                                  title: '训练经验',
                                  category:
                                      AiProfileCategory.trainingExperience,
                                  current: summary?.trainingExperience,
                                  options: const ['初学', '有一定经验', '熟练训练者'],
                                  allowUnset: true,
                                ),
                              ),
                              _ActionRow(
                                id: ProfileActionId.equipment,
                                icon: Icons.fitness_center_outlined,
                                title: '可用器械',
                                value: _equipmentLabel(
                                  summary?.availableEquipment ?? const [],
                                ),
                                onTap: () => _openEquipment(
                                  summary?.availableEquipment ?? const [],
                                ),
                              ),
                              _ActionRow(
                                id: ProfileActionId.trainingPreferences,
                                icon: Icons.tune_outlined,
                                title: '训练偏好',
                                subtitle: '喜欢的形式、不喜欢的动作与明确限制',
                                onTap: () => _run(widget.onOpenAiProfile),
                              ),
                              _ActionRow(
                                id: ProfileActionId.coachingStyle,
                                icon: Icons.record_voice_over_outlined,
                                title: '指导风格',
                                value: summary?.coachingStyle ?? '未设置',
                                onTap: () => _openSingleChoice(
                                  title: '指导风格',
                                  category: AiProfileCategory.coachingStyle,
                                  current: summary?.coachingStyle,
                                  options: const ['简洁直接', '详细解释', '鼓励型', '数据型'],
                                  allowUnset: true,
                                ),
                              ),
                              _ActionRow(
                                id: ProfileActionId.trainingPlans,
                                icon: Icons.event_note_outlined,
                                title: '我的训练方案',
                                value: summary == null
                                    ? null
                                    : summary.templateCount == 0
                                    ? '尚未创建'
                                    : '${summary.templateCount} 个方案',
                                onTap: () => _run(widget.onManageTrainingPlans),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionTitle(title: 'GOAT AI'),
                          _SectionCard(
                            children: [
                              _ActionRow(
                                id: ProfileActionId.aiProfile,
                                icon: Icons.psychology_alt_outlined,
                                title: 'AI 对我的了解',
                                subtitle: summary == null
                                    ? '由你掌控的个人教练信息'
                                    : summary.activeMemoryCount == 0
                                    ? '告诉 GOAT 你的目标和偏好'
                                    : '${summary.activeMemoryCount} 条有效信息',
                                badge: (summary?.pendingMemoryCount ?? 0) > 0
                                    ? '${summary!.pendingMemoryCount} 条待确认'
                                    : null,
                                aiAccent: true,
                                onTap: () => _run(widget.onOpenAiProfile),
                              ),
                              _ActionRow(
                                id: ProfileActionId.suggestionHistory,
                                icon: Icons.auto_awesome_outlined,
                                title: 'GOAT 建议记录',
                                subtitle: '查看待处理、已采用与已忽略的建议',
                                aiAccent: true,
                                onTap: () =>
                                    _run(widget.onOpenSuggestionHistory),
                              ),
                              _ActionRow(
                                id: ProfileActionId.knowledgeExplanation,
                                icon: Icons.fact_check_outlined,
                                title: 'GOAT 如何给出建议',
                                subtitle: '了解数据、分析引擎与知识依据',
                                aiAccent: true,
                                onTap: () =>
                                    _run(widget.onOpenKnowledgeExplanation),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionTitle(title: '健康与记录'),
                          _SectionCard(
                            children: [
                              _ActionRow(
                                id: ProfileActionId.weightHistory,
                                icon: Icons.monitor_weight_outlined,
                                title: '体重与目标',
                                value: summary?.weightLabel,
                                onTap: () => _run(widget.onOpenWeightHistory),
                              ),
                              _ActionRow(
                                id: ProfileActionId.trainingHistory,
                                icon: Icons.history_outlined,
                                title: '训练历史',
                                value: summary == null
                                    ? null
                                    : '${summary.totalTrainingSessions} 次',
                                onTap: () => _run(widget.onOpenTrainingHistory),
                              ),
                              _ActionRow(
                                id: ProfileActionId.weeklyReview,
                                icon: Icons.insights_outlined,
                                title: '周复盘',
                                value: summary == null
                                    ? null
                                    : '${summary.weeklyEffectiveSets} 个有效组',
                                onTap: () => _run(widget.onOpenWeeklyReview),
                              ),
                              _ActionRow(
                                id: ProfileActionId.allRecords,
                                icon: Icons.grid_view_outlined,
                                title: '查看全部记录',
                                subtitle: '饮食、饮水、体重与训练入口',
                                onTap: () => _run(widget.onOpenAllRecords),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionTitle(title: '数据与隐私'),
                          _SectionCard(
                            children: [
                              _ActionRow(
                                id: ProfileActionId.dataPrivacy,
                                icon: Icons.shield_outlined,
                                title: '数据与隐私',
                                subtitle: widget.identity.isLoggedIn
                                    ? '导出、AI 数据、本地数据与账户控制'
                                    : '本地数据说明与设备数据导出',
                                onTap: () => _run(widget.onOpenDataPrivacy),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionTitle(title: '应用'),
                          _SectionCard(
                            children: [
                              _ActionRow(
                                id: ProfileActionId.about,
                                icon: Icons.info_outline,
                                title: '关于 GOAT',
                                subtitle: '版本、产品定位与隐私入口',
                                onTap: () => _run(widget.onOpenAbout),
                              ),
                              _ActionRow(
                                id: ProfileActionId.licenses,
                                icon: Icons.article_outlined,
                                title: '开源许可',
                                onTap: () => _run(widget.onOpenLicenses),
                              ),
                            ],
                          ),
                          if (widget.identity.isLoggedIn) ...[
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const Key('profile-logout'),
                                onPressed: () => _confirmLogout(context),
                                icon: const Icon(Icons.logout, size: 18),
                                label: const Text('退出登录'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF68716F),
                                  side: const BorderSide(
                                    color: Color(0xFFD9DEDC),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Future<void> _openEditProfile(ProfileIdentity identity) async {
    final update = await EditProfileSheet.show(
      context,
      identity: identity,
      data: widget.basicData,
    );
    if (update == null) return;
    await _run(() => widget.onSaveBasic(update));
  }

  Future<void> _openSingleChoice({
    required String title,
    required AiProfileCategory category,
    required String? current,
    required List<String> options,
    bool allowUnset = false,
  }) async {
    final value = await _SingleChoiceSheet.show(
      context,
      title: title,
      current: current,
      options: options,
      allowUnset: allowUnset,
    );
    if (!mounted || value == _SingleChoiceSheet.cancelled) return;
    await _run(() => widget.onSaveProfileValue(category, value));
  }

  Future<void> _openEquipment(List<String> current) async {
    final selected = await _EquipmentSheet.show(
      context,
      options: widget.equipmentOptions,
      selected: current,
    );
    if (selected == null) return;
    await _run(
      () => widget.onSaveProfileValue(
        AiProfileCategory.availableEquipment,
        selected.isEmpty ? null : selected.join('、'),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '退出登录？',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '本设备上的本地记录会保留。再次登录后仍可继续使用。',
                style: TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('profile-logout-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _marsGreen,
                      ),
                      child: const Text('退出'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await _run(widget.onLogout);
  }

  String _equipmentLabel(List<String> values) {
    if (values.isEmpty) return '未设置';
    if (values.length <= 2) return values.join('、');
    return '${values.take(2).join('、')}等 ${values.length} 项';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.identity,
    required this.trainingGoal,
    required this.weeklyTrainingDays,
    required this.onEdit,
    required this.onLogin,
  });

  final ProfileIdentity identity;
  final String? trainingGoal;
  final int? weeklyTrainingDays;
  final VoidCallback onEdit;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => _CardSurface(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: const Color(0xFFE4F2F0),
          child: Text(
            identity.avatarLetter,
            style: const TextStyle(
              color: _marsGreen,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                identity.resolvedName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _charcoal,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                identity.isLoggedIn ? identity.email : '登录后可使用云端账户功能',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  if (trainingGoal != null) _NeutralTag(label: trainingGoal!),
                  if (weeklyTrainingDays != null)
                    _NeutralTag(label: '本周 ${weeklyTrainingDays!} 天'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: Key(
            identity.isLoggedIn ? 'profile-edit-entry' : 'profile-login-entry',
          ),
          onPressed: identity.isLoggedIn ? onEdit : onLogin,
          style: TextButton.styleFrom(
            foregroundColor: _marsGreen,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(identity.isLoggedIn ? '编辑' : '登录'),
        ),
      ],
    ),
  );
}

class _ProgressSummaryCard extends StatelessWidget {
  const _ProgressSummaryCard({
    required this.summary,
    required this.loading,
    required this.onTraining,
    required this.onWeekly,
    required this.onWeight,
  });

  final ProfileSummary? summary;
  final bool loading;
  final VoidCallback onTraining;
  final VoidCallback onWeekly;
  final VoidCallback onWeight;

  @override
  Widget build(BuildContext context) => _CardSurface(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    child: Row(
      children: [
        _SummaryMetric(
          key: const Key('profile-summary-training'),
          label: '训练记录',
          value: loading ? '···' : '${summary?.totalTrainingSessions ?? 0} 次',
          onTap: onTraining,
        ),
        _SummaryDivider(),
        _SummaryMetric(
          key: const Key('profile-summary-weekly'),
          label: '本周训练',
          value: loading ? '···' : '${summary?.weeklyTrainingDays ?? 0} 天',
          onTap: onWeekly,
        ),
        _SummaryDivider(),
        _SummaryMetric(
          key: const Key('profile-summary-weight'),
          label: '趋势体重',
          value: loading ? '···' : summary?.weightLabel ?? '--',
          onTap: onWeight,
        ),
      ],
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(
                color: _charcoal,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 34, child: VerticalDivider(width: 1));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      title,
      style: const TextStyle(
        color: _charcoal,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _CardSurface(
    padding: EdgeInsets.zero,
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.id,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.badge,
    this.aiAccent = false,
  });

  final ProfileActionId id;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final String? badge;
  final bool aiAccent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('profile-action-${id.name}'),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: aiAccent ? const Color(0xFF4D6BFE) : _marsGreen,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _charcoal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: _marsGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (value != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFB1B8B6),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _NeutralTag extends StatelessWidget {
  const _NeutralTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4F3),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF56615E),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.identity,
    required this.data,
  });

  final ProfileIdentity identity;
  final ProfileBasicData data;

  static Future<ProfileBasicUpdate?> show(
    BuildContext context, {
    required ProfileIdentity identity,
    required ProfileBasicData data,
  }) => showModalBottomSheet<ProfileBasicUpdate>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => EditProfileSheet(identity: identity, data: data),
  );

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _height;
  late final TextEditingController _birthYear;
  late String _gender;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.identity.displayName);
    _height = TextEditingController(
      text: widget.data.heightCm.toStringAsFixed(0),
    );
    _birthYear = TextEditingController(text: widget.data.birthYear.toString());
    _gender = widget.data.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _birthYear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '编辑个人资料',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '仅编辑当前已有的数据字段。',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (widget.identity.isLoggedIn) ...[
              TextFormField(
                key: const Key('profile-edit-name'),
                controller: _name,
                textInputAction: TextInputAction.next,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '显示名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入显示名称' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const Key('profile-edit-height'),
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '身高（cm）',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                return parsed == null || parsed < 90 || parsed > 250
                    ? '请输入 90–250 cm'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('profile-edit-birth-year'),
              controller: _birthYear,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '出生年份',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                final latest = DateTime.now().year;
                return parsed == null || parsed < 1920 || parsed > latest
                    ? '请输入有效年份'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('profile-edit-gender'),
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: '性别',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '男', child: Text('男')),
                DropdownMenuItem(value: '女', child: Text('女')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _gender = value);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('profile-edit-save'),
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _marsGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ProfileBasicUpdate(
        displayName: widget.identity.isLoggedIn ? _name.text.trim() : '',
        gender: _gender,
        birthYear: int.parse(_birthYear.text),
        heightCm: double.parse(_height.text),
      ),
    );
  }
}

class _SingleChoiceSheet extends StatelessWidget {
  const _SingleChoiceSheet({
    required this.title,
    required this.current,
    required this.options,
    required this.allowUnset,
  });

  static const cancelled = '__cancelled__';
  final String title;
  final String? current;
  final List<String> options;
  final bool allowUnset;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String? current,
    required List<String> options,
    required bool allowUnset,
  }) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SingleChoiceSheet(
        title: title,
        current: current,
        options: options,
        allowUnset: allowUnset,
      ),
    );
    return result ?? cancelled;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final option in options)
            RadioListTile<String>(
              value: option,
              // ignore: deprecated_member_use
              groupValue: current,
              // ignore: deprecated_member_use
              onChanged: (_) => Navigator.pop(context, option),
              activeColor: _marsGreen,
              title: Text(option),
              contentPadding: EdgeInsets.zero,
            ),
          if (allowUnset)
            ListTile(
              key: const Key('profile-choice-unset'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('恢复为未设置'),
              onTap: () => Navigator.pop(context, ''),
            ),
        ],
      ),
    ),
  );
}

class _EquipmentSheet extends StatefulWidget {
  const _EquipmentSheet({required this.options, required this.selected});

  final List<String> options;
  final List<String> selected;

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> options,
    required List<String> selected,
  }) => showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _EquipmentSheet(options: options, selected: selected),
  );

  @override
  State<_EquipmentSheet> createState() => _EquipmentSheetState();
}

class _EquipmentSheetState extends State<_EquipmentSheet> {
  late final Set<String> _selected = widget.selected.toSet();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '可用器械',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        const Text(
          '选项与当前动作库的器械分类保持一致。',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in widget.options)
                  FilterChip(
                    label: Text(option),
                    selected: _selected.contains(option),
                    selectedColor: const Color(0xFFDDEFEA),
                    checkmarkColor: _marsGreen,
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selected.add(option);
                      } else {
                        _selected.remove(option);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('profile-equipment-save'),
            onPressed: () {
              final ordered = widget.options
                  .where(_selected.contains)
                  .toList(growable: false);
              Navigator.pop(context, ordered);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _marsGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    ),
  );
}
