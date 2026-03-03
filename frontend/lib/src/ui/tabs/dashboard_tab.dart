import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.controller,
    this.onRequestTabChange,
  });

  final NestController controller;
  final ValueChanged<String>? onRequestTabChange;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _formKey = GlobalKey<FormState>();
  final _homeschoolController = TextEditingController(text: 'Nest Warm Home');
  final _termController = TextEditingController(text: '2026 Spring');
  final _classController = TextEditingController(text: 'Robin Class');
  final _courseController = TextEditingController(text: '국어, 수학, 자연탐구, 미술');

  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 4, now.day);
    _startDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(now),
    );
    _endDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(end),
    );
  }

  @override
  void dispose() {
    _homeschoolController.dispose();
    _termController.dispose();
    _classController.dispose();
    _courseController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('현재 뷰', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '활성 역할: ${controller.currentRole ?? 'NONE'}',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  controller.isParentView
                      ? '부모 뷰에서는 내 아이의 시간표/갤러리를 중심으로 확인합니다.'
                      : controller.isTeacherView
                      ? '교사 뷰에서는 수업 운영과 활동 기록 중심으로 확인합니다.'
                      : controller.isAdminLike
                      ? '관리자 뷰에서는 운영/권한/신고 등 전체 관리 기능을 사용합니다.'
                      : '역할을 선택하면 해당 뷰에 맞는 기능이 활성화됩니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (controller.pendingInvites.isNotEmpty) ...[
          const SizedBox(height: 16),
          _PendingInvitesCard(controller: controller),
        ],
        if (controller.isAdminLike) ...[
          const SizedBox(height: 16),
          _buildAdminSetupFlowCard(theme, controller),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              label: '소속 홈스쿨',
              value: '${controller.memberships.length}',
              icon: Icons.house,
            ),
            _SummaryCard(
              label: '학기',
              value: '${controller.terms.length}',
              icon: Icons.calendar_month,
            ),
            _SummaryCard(
              label: '반',
              value: '${controller.classGroups.length}',
              icon: Icons.groups,
            ),
            _SummaryCard(
              label: '활성 수업',
              value: '${controller.sessions.length}',
              icon: Icons.view_week,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('최근 공지', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (controller.announcements.isEmpty)
                  const Text('등록된 공지가 없습니다.')
                else
                  ...controller.announcements.take(3).map((notice) {
                    final scope = notice.classGroupId == null
                        ? '전체'
                        : controller.findClassGroupName(notice.classGroupId);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${notice.pinned ? '[PIN] ' : ''}${notice.title}',
                      ),
                      subtitle: Text('$scope · ${notice.body}'),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (controller.isAdminLike)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('빠른 초기 세팅', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '관리 운영의 기본 틀(홈스쿨, 학기, 반, 과목, 시간 슬롯)을 자동으로 만듭니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _homeschoolController,
                      decoration: const InputDecoration(labelText: '홈스쿨 이름'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '필수값입니다.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _termController,
                      decoration: const InputDecoration(labelText: '학기 이름'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '필수값입니다.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startDateController,
                            decoration: const InputDecoration(
                              labelText: '시작일 (YYYY-MM-DD)',
                            ),
                            validator: _validateDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _endDateController,
                            decoration: const InputDecoration(
                              labelText: '종료일 (YYYY-MM-DD)',
                            ),
                            validator: _validateDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _classController,
                      decoration: const InputDecoration(labelText: '반 이름'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '필수값입니다.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _courseController,
                      decoration: const InputDecoration(
                        labelText: '기본 과목 (콤마 구분)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: controller.isBusy ? null : _submitBootstrap,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('운영 틀 생성'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '관리 기능(초기 세팅, 권한 관리, Drive 설정)은 관리자 뷰에서 사용할 수 있습니다.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
      ],
    );
  }

  String? _validateDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '필수값입니다.';
    }

    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return 'YYYY-MM-DD 형식으로 입력하세요.';
    }

    return null;
  }

  Widget _buildAdminSetupFlowCard(ThemeData theme, NestController controller) {
    final steps = _setupSteps(controller);
    final completedCount = steps.where((step) => step.completed).length;
    _SetupStep? nextStep;
    for (final step in steps) {
      if (!step.completed && step.enabled) {
        nextStep = step;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('학기 설정 가이드', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '관리자는 순서대로 진행하면 홈스쿨 운영 틀을 빠르게 완성할 수 있습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: steps.isEmpty ? 0 : completedCount / steps.length,
                color: NestColors.dustyRose,
                backgroundColor: NestColors.roseMist,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '완료 $completedCount / ${steps.length}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SetupStepTile(
                  step: step,
                  onOpen: widget.onRequestTabChange == null || !step.enabled
                      ? null
                      : () => widget.onRequestTabChange!.call(step.targetTab),
                ),
              ),
            ),
            if (nextStep != null) ...[
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final actionableStep = nextStep!;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: widget.onRequestTabChange == null
                          ? null
                          : () => widget.onRequestTabChange!.call(
                              actionableStep.targetTab,
                            ),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        '다음 단계: ${actionableStep.order}. ${actionableStep.title}',
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_SetupStep> _setupSteps(NestController controller) {
    final hasHomeschool = controller.selectedHomeschoolId != null;
    final hasTerm = controller.selectedTermId != null;
    final hasClass = controller.classGroups.isNotEmpty;
    final hasCourses = controller.courses.isNotEmpty;
    final hasSlots = controller.timeSlots.isNotEmpty;

    return [
      _SetupStep(
        order: 1,
        title: '가정 관리',
        description: '가정을 만들고 아이를 등록합니다.',
        targetTab: 'Families',
        actionLabel: '가정/아이 설정 열기',
        completed:
            controller.families.isNotEmpty && controller.children.isNotEmpty,
        enabled: hasHomeschool,
      ),
      _SetupStep(
        order: 2,
        title: '반 관리',
        description: '반을 만들고 아이를 반에 배정합니다.',
        targetTab: 'Families',
        actionLabel: '반/배정 설정 열기',
        completed:
            controller.classGroups.isNotEmpty &&
            controller.classEnrollments.isNotEmpty,
        enabled: hasTerm,
      ),
      _SetupStep(
        order: 3,
        title: '과목 관리',
        description: '과목을 준비하고 시간표에서 반에 배정합니다.',
        targetTab: 'Timetable',
        actionLabel: '과목/수업 편성 열기',
        completed: hasCourses && hasClass,
        enabled: hasHomeschool,
      ),
      _SetupStep(
        order: 4,
        title: '시간표 관리',
        description: '이번 학기의 시간표를 생성/보정하고 확정합니다.',
        targetTab: 'Timetable',
        actionLabel: '시간표 관리 열기',
        completed: controller.sessions.isNotEmpty,
        enabled: hasTerm && hasClass && hasCourses && hasSlots,
      ),
    ];
  }

  Future<void> _submitBootstrap() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    try {
      await widget.controller.bootstrapFrame(
        homeschoolName: _homeschoolController.text,
        termName: _termController.text,
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        className: _classController.text,
        coursesCsv: _courseController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    }
  }
}

class _PendingInvitesCard extends StatelessWidget {
  const _PendingInvitesCard({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final pending =
        controller.pendingInvites
            .where((invite) => invite.canAccept)
            .toList(growable: false)
          ..sort((a, b) {
            final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return right.compareTo(left);
          });

    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('대기 중 초대', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '홈스쿨 관리자에게 받은 초대를 수락하면 바로 멤버십이 활성화됩니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            ...pending.map(
              (invite) => _InviteItem(controller: controller, invite: invite),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteItem extends StatelessWidget {
  const _InviteItem({required this.controller, required this.invite});

  final NestController controller;
  final HomeschoolInvite invite;

  @override
  Widget build(BuildContext context) {
    final created = invite.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(invite.createdAt!);
    final expires = invite.expiresAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd').format(invite.expiresAt!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NestColors.roseMist),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(invite.homeschoolName)),
                Chip(label: Text(invite.role)),
                Chip(label: Text('만료: $expires')),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '초대 생성: $created',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () async {
                      try {
                        await controller.acceptPendingInvite(
                          invite.inviteToken,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(controller.statusMessage)),
                        );
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(controller.statusMessage)),
                        );
                      }
                    },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('초대 수락'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: NestColors.roseMist,
                foregroundColor: NestColors.deepWood,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(value, style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupStep {
  const _SetupStep({
    required this.order,
    required this.title,
    required this.description,
    required this.targetTab,
    required this.actionLabel,
    required this.completed,
    required this.enabled,
  });

  final int order;
  final String title;
  final String description;
  final String targetTab;
  final String actionLabel;
  final bool completed;
  final bool enabled;
}

class _SetupStepTile extends StatelessWidget {
  const _SetupStepTile({required this.step, this.onOpen});

  final _SetupStep step;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isDone = step.completed;
    final active = step.enabled;
    final borderColor = isDone ? Colors.green.shade400 : NestColors.roseMist;
    final badgeBg = isDone ? Colors.green.shade50 : NestColors.creamyWhite;
    final badgeFg = isDone ? Colors.green.shade800 : NestColors.deepWood;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        color: active ? Colors.white : Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isDone
                    ? Colors.green.shade600
                    : NestColors.dustyRose,
                foregroundColor: Colors.white,
                child: isDone
                    ? const Icon(Icons.check, size: 14)
                    : Text(
                        '${step.order}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${step.order}. ${step.title}', style: titleStyle),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDone ? Colors.green.shade200 : NestColors.roseMist,
                  ),
                ),
                child: Text(
                  isDone ? '완료' : (active ? '진행 필요' : '선행 단계 필요'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: badgeFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NestColors.deepWood.withValues(
                alpha: active ? 0.78 : 0.52,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: active ? onOpen : null,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(step.actionLabel),
          ),
        ],
      ),
    );
  }
}
