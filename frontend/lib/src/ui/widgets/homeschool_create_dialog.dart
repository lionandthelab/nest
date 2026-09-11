import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../models/homeschool_start_tips.dart';
import '../nest_theme.dart';
import 'nest_motion.dart';

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
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
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
                      child: Form(
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
