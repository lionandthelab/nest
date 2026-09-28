import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../models/homeschool_start_tips.dart';
import '../nest_theme.dart';
import '../tabs/album/album_drive_connect_sheet.dart';
import 'nest_3d_icon.dart';
import 'nest_motion.dart';

enum _Step { form, driveOnboarding }

/// 우리집 홈스쿨을 바로 열 수 있게, 기본값을 채워 두는 생성 화면.
class HomeschoolCreateDialog extends StatefulWidget {
  const HomeschoolCreateDialog({super.key, required this.controller});

  final NestController controller;

  @override
  State<HomeschoolCreateDialog> createState() => _HomeschoolCreateDialogState();
}

class _HomeschoolCreateDialogState extends State<HomeschoolCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _homeschoolController;
  late final TextEditingController _termController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _classController;
  late final TextEditingController _courseController;
  _Step _step = _Step.form;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final nickname = widget.controller.user?.userMetadata?['full_name'];
    _homeschoolController = TextEditingController(
      text: HomeschoolStartDefaults.nameFromProfile(
        realName: widget.controller.myRealName,
        nickname: nickname is String ? nickname : '',
      ),
    );
    _termController = TextEditingController(
      text: HomeschoolStartDefaults.termName(now),
    );
    _startDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(now),
    );
    _endDateController = TextEditingController(
      text: DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(now.year, now.month + 6, now.day)),
    );
    _classController = TextEditingController(
      text: HomeschoolStartDefaults.defaultClassName,
    );
    _courseController = TextEditingController(
      text: HomeschoolStartDefaults.defaultCourses,
    );
  }

  @override
  void dispose() {
    _homeschoolController.dispose();
    _termController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _classController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  bool get _isLocked => _submitting || widget.controller.isBusy;

  String? _validateDate(String? value) {
    if (value == null || value.trim().isEmpty) return '날짜를 골라 주세요.';
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return '날짜를 다시 골라 주세요.';
    return null;
  }

  Future<void> _pickDate(TextEditingController target) async {
    if (_isLocked) return;
    final parsed = DateTime.tryParse(target.text.trim());
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    target.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  Future<void> _onStart() async {
    if (_submitting) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _submitting = true);
    try {
      await widget.controller.bootstrapFrame(
        homeschoolName: _homeschoolController.text,
        termName: _termController.text,
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        className: _classController.text,
        coursesCsv: _courseController.text,
      );
      if (!mounted) return;
      NestHaptics.success();
      unawaited(widget.controller.loadDriveIntegration());
      setState(() {
        _submitting = false;
        _step = _Step.driveOnboarding;
      });
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onConnectDriveInOnboarding() async {
    await showDriveConnectSheet(
      context: context,
      controller: widget.controller,
    );
    if (!mounted) return;
    setState(() {});
  }

  InputDecoration _field({
    required String label,
    String? hint,
    String? helper,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 3,
      errorMaxLines: 2,
      suffixIcon: suffix,
    );
  }

  Widget _startLabel() {
    if (!_isLocked) return const Text('바로 시작하기');
    return const Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('만들고 있어요'),
      ],
    );
  }

  List<Widget> _actions({required bool stacked}) {
    final start = NestPressable(
      enabled: !_isLocked,
      child: stacked
          ? SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLocked ? null : _onStart,
                child: _startLabel(),
              ),
            )
          : FilledButton(
              onPressed: _isLocked ? null : _onStart,
              child: _startLabel(),
            ),
    );
    final close = stacked
        ? SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isLocked
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('닫기'),
            ),
          )
        : TextButton(
            onPressed: _isLocked
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('닫기'),
          );

    if (stacked) {
      return [start, const SizedBox(height: 8), close];
    }
    return [close, const SizedBox(width: 8), start];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 520;
    final maxWidth = isNarrow ? double.infinity : 680.0;
    final dialogHeight = MediaQuery.sizeOf(context).height * 0.86;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final locked = _isLocked;
        return PopScope(
          canPop: !locked,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_step == _Step.driveOnboarding) {
              Navigator.of(context).pop(true);
            }
          },
          child: Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 12 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: dialogHeight.clamp(360.0, 720.0),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: AbsorbPointer(
                      absorbing: locked,
                      child: _step == _Step.driveOnboarding
                          ? _buildDriveOnboardingContent(context, isNarrow)
                          : Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '우리집 홈스쿨 시작하기',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                            const SizedBox(height: 8),
                            Text(
                              '기본값은 이미 넣어 두었어요. 이름만 보고 바로 시작해도 됩니다.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: NestColors.deepWood.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _homeschoolController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _field(
                                label: '우리집 홈스쿨 이름',
                                hint: '예: 민지네 집',
                                helper: '나중에 설정에서 바꿔도 돼요.',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? '이름을 적어 주세요.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _termController,
                              decoration: _field(
                                label: '첫 학기',
                                hint: '예: 2026 가을 학기',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? '학기 이름을 적어 주세요.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _startDateController,
                                    readOnly: true,
                                    onTap: () =>
                                        _pickDate(_startDateController),
                                    decoration: _field(
                                      label: '시작일',
                                      suffix: const Icon(Icons.event_outlined),
                                    ),
                                    validator: _validateDate,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _endDateController,
                                    readOnly: true,
                                    onTap: () => _pickDate(_endDateController),
                                    decoration: _field(
                                      label: '종료일',
                                      suffix: const Icon(Icons.event_outlined),
                                    ),
                                    validator: _validateDate,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _classController,
                              decoration: _field(
                                label: '반 이름',
                                hint: '예: 우리 반',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? '반 이름을 적어 주세요.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _courseController,
                              decoration: _field(
                                label: '과목',
                                hint: '예: 국어, 수학, 영어',
                                helper: '콤마로 나누면 됩니다. 나중에 더 넣어도 돼요.',
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (isNarrow)
                              ..._actions(stacked: true)
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: _actions(stacked: false),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: NestBusyOverlay(
                      visible: locked,
                      message: widget.controller.statusMessage.isEmpty
                          ? '우리집 홈스쿨을 만드는 중...'
                          : widget.controller.statusMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriveOnboardingContent(BuildContext context, bool isNarrow) {
    final theme = Theme.of(context);
    final isDriveConnected = widget.controller.isAlbumActive;
    final homeschoolName = _homeschoolController.text.trim().isEmpty
        ? '우리집 홈스쿨'
        : _homeschoolController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Nest3dIcon.star(
          size: 72,
          floating: true,
        ),
        const SizedBox(height: 16),
        Text(
          '🎉 $homeschoolName 개설 완료!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: NestColors.deepWood,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '홈스쿨 공간이 성공적으로 준비되었습니다.\n아이들의 학습과 활동 사진을 보관할 준비를 시작해 보세요.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: NestColors.deepWood.withValues(alpha: 0.72),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDriveConnected
                ? NestColors.mutedSage.withValues(alpha: 0.15)
                : NestColors.roseMist.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDriveConnected
                  ? NestColors.mutedSage.withValues(alpha: 0.6)
                  : NestColors.roseMist,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isDriveConnected
                          ? Icons.cloud_done_rounded
                          : Icons.add_to_drive_rounded,
                      size: 20,
                      color: isDriveConnected
                          ? NestColors.mutedSage
                          : NestColors.dustyRose,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDriveConnected
                              ? 'Google Drive 연동 완료 (앨범 활성화됨)'
                              : '사진 보관용 Google Drive 연동 (권장)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: NestColors.deepWood,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDriveConnected
                              ? '이제 모든 가족이 앨범을 이용할 수 있습니다.'
                              : '앨범 기능을 활성화하려면 관리자 Drive 연동이 필요합니다.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: NestColors.deepWood.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isDriveConnected) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildBulletItem(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  text: '관리자 개인 Google Drive에 안전하고 무제한 원본 저장',
                ),
                const SizedBox(height: 8),
                _buildBulletItem(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  text: '학기·수업·날짜별 스마트 자동 폴더 생성 및 정리',
                ),
                const SizedBox(height: 8),
                _buildBulletItem(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  text: '초대된 가족들과 고화질 활동 사진 실시간 공유',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (isDriveConnected) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: NestColors.dustyRose,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '홈스쿨 시작하기',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: NestPressable(
              haptic: true,
              onPressed: _onConnectDriveInOnboarding,
              child: FilledButton.icon(
                onPressed: _onConnectDriveInOnboarding,
                style: FilledButton.styleFrom(
                  backgroundColor: NestColors.dustyRose,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_to_drive, size: 18),
                label: const Text(
                  'Google Drive 연동하기 (권장)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '나중에 하기 (홈스쿨 바로 시작)',
                style: TextStyle(
                  color: NestColors.deepWood.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '앨범 탭에서 언제든지 연동하여 앨범을 활성화할 수 있습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: NestColors.deepWood.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildBulletItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: NestColors.clay),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.8),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Returns `true` if the homeschool was created successfully.
Future<bool> showHomeschoolCreateDialog({
  required BuildContext context,
  required NestController controller,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: NestMotion.sheet,
    pageBuilder: (context, animation, secondaryAnimation) {
      return HomeschoolCreateDialog(controller: controller);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return nestFadeSlideTransition(
        child,
        animation,
        beginOffset: const Offset(0, 0.04),
      );
    },
  );
  return result == true;
}
