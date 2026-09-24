import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../models/admin_self_setup.dart';
import '../nest_theme.dart';

/// 관리자 홈 맨 위의 "나도 함께하기" 카드.
///
/// 아직 안 된 항목만 한 번 누르면 끝나는 버튼으로 보여 주고, 다 되면 카드가
/// 사라진다. 각 버튼은 멤버·가정·선생님 화면을 찾아가지 않고 그 자리에서 처리한다.
class AdminSelfSetupCard extends StatefulWidget {
  const AdminSelfSetupCard({
    super.key,
    required this.controller,
    this.margin = EdgeInsets.zero,
  });

  final NestController controller;

  /// 카드가 보일 때만 주는 바깥 여백. 다 끝나 사라지면 틈도 남기지 않는다.
  final EdgeInsetsGeometry margin;

  @override
  State<AdminSelfSetupCard> createState() => _AdminSelfSetupCardState();
}

class _AdminSelfSetupCardState extends State<AdminSelfSetupCard> {
  SelfSetupAction? _running;

  NestController get _controller => widget.controller;

  List<SelfSetupAction> get _pending => pendingSelfSetupActions(
    hasOwnFamily: _controller.hasOwnFamily,
    isParent: _controller.isSelfParent,
    hasTeacherProfile: _controller.hasSelfTeacherProfile,
    hasTerm: _controller.selectedTermId != null,
    classroomCount: _controller.classrooms.length,
  );

  Future<void> _run(SelfSetupAction action) async {
    if (_running != null) return;
    setState(() => _running = action);
    try {
      await switch (action) {
        SelfSetupAction.family => _controller.createMyFamily(),
        SelfSetupAction.parent => _controller.registerSelfAsParent(),
        SelfSetupAction.teacher => _controller.registerSelfAsTeacher(),
        SelfSetupAction.classroom => _controller.addDefaultClassroom(),
      };
      _snack(_doneMessage(action));
    } catch (error) {
      _snack(error is StateError ? error.message : _controller.statusMessage);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static String _doneMessage(SelfSetupAction action) => switch (action) {
    SelfSetupAction.family => '우리 가정을 만들고 보호자로 연결했어요.',
    SelfSetupAction.parent => '학부모로 등록했어요.',
    SelfSetupAction.teacher => '선생님으로 등록했어요.',
    SelfSetupAction.classroom => "'집' 교실을 추가했어요.",
  };

  static (IconData, String, String) _describe(SelfSetupAction action) =>
      switch (action) {
        SelfSetupAction.family => (
          Icons.family_restroom_outlined,
          '우리 가정 만들기',
          '내 이름으로 가정을 만들고 보호자로 연결해요.',
        ),
        SelfSetupAction.parent => (
          Icons.escalator_warning_outlined,
          '학부모로 등록',
          '학부모 화면에서 우리 아이 소식을 볼 수 있어요.',
        ),
        SelfSetupAction.teacher => (
          Icons.school_outlined,
          '선생님으로 등록',
          '선생님 명단에 올라 수업을 맡을 수 있어요.',
        ),
        SelfSetupAction.classroom => (
          Icons.cottage_outlined,
          "'집' 교실 추가",
          '시간표에 바로 쓸 수 있는 기본 교실이에요.',
        ),
      };

  @override
  Widget build(BuildContext context) {
    // 로그인 사용자가 없으면 스스로 등록할 대상도 없다.
    if (_controller.user == null) return const SizedBox.shrink();
    final pending = _pending;
    if (pending.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: widget.margin,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.waving_hand_outlined,
                    size: 20,
                    color: NestColors.clay,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '나도 함께하기',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '관리자도 우리 집 부모이자 선생님이라면, 한 번씩 눌러 바로 등록하세요.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 12),
              for (final action in pending) ...[
                _SetupTile(
                  describe: _describe(action),
                  isRunning: _running == action,
                  enabled: _running == null && !_controller.isBusy,
                  onPressed: () => _run(action),
                ),
                if (action != pending.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.describe,
    required this.isRunning,
    required this.enabled,
    required this.onPressed,
  });

  final (IconData, String, String) describe;
  final bool isRunning;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, help) = describe;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: NestColors.roseMist.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: NestColors.clay),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: NestColors.deepWood,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  help,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('하기'),
          ),
        ],
      ),
    );
  }
}
