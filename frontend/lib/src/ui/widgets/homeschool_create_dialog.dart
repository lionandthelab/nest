import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

/// Reusable dialog for creating a new homeschool with term, class, and courses.
/// Used from both the onboarding dashboard and the homeschool switcher sheet.
class HomeschoolCreateDialog extends StatefulWidget {
  const HomeschoolCreateDialog({super.key, required this.controller});

  final NestController controller;

  @override
  State<HomeschoolCreateDialog> createState() => _HomeschoolCreateDialogState();
}

class _HomeschoolCreateDialogState extends State<HomeschoolCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _homeschoolController = TextEditingController(text: 'Nest Warm Home');
  final _termController = TextEditingController(text: '1학기');
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _classController = TextEditingController(text: '기본반');
  final _courseController = TextEditingController(text: '국어, 수학, 영어, 과학');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDateController.text = DateFormat('yyyy-MM-dd').format(now);
    _endDateController.text = DateFormat('yyyy-MM-dd').format(
      DateTime(now.year, now.month + 6, now.day),
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

  String? _validateDate(String? value) {
    if (value == null || value.trim().isEmpty) return '필수값입니다.';
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return 'YYYY-MM-DD 형식이어야 합니다.';
    return null;
  }

  Future<bool> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return false;

    try {
      await widget.controller.bootstrapFrame(
        homeschoolName: _homeschoolController.text,
        termName: _termController.text,
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        className: _classController.text,
        coursesCsv: _courseController.text,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final maxWidth =
        MediaQuery.of(context).size.width < 700 ? double.infinity : 680.0;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '홈스쿨 개설',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '운영에 필요한 기본 틀을 한 번에 생성합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: controller.isBusy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('닫기'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () async {
                              final ok = await _submit();
                              if (!context.mounted) return;
                              Navigator.of(context).pop(ok);
                            },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('홈스쿨 개설하기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience function to show the HomeschoolCreateDialog.
/// Returns `true` if the homeschool was created successfully.
Future<bool> showHomeschoolCreateDialog({
  required BuildContext context,
  required NestController controller,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !controller.isBusy,
    builder: (_) => HomeschoolCreateDialog(controller: controller),
  );
  return result == true;
}
