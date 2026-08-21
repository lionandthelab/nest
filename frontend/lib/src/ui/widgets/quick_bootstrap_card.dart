import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

/// 빠른 초기 세팅 카드.
///
/// 학기·반·과목이 아직 하나도 없는 홈스쿨에서 운영 틀(학기, 반, 과목, 시간 슬롯)을
/// 한 번에 만든다. 단계별로 진행하고 싶으면 신학기 체크리스트를 따라가면 되므로,
/// 이 카드는 기본으로 접혀 있고 "한 번에 만들기"를 원할 때만 펼친다.
class QuickBootstrapCard extends StatefulWidget {
  const QuickBootstrapCard({super.key, required this.controller});

  final NestController controller;

  @override
  State<QuickBootstrapCard> createState() => _QuickBootstrapCardState();
}

class _QuickBootstrapCardState extends State<QuickBootstrapCard> {
  final _formKey = GlobalKey<FormState>();
  final _homeschoolController = TextEditingController();
  final _termController = TextEditingController();
  final _classController = TextEditingController(text: '1반');
  final _courseController = TextEditingController(text: '국어, 수학, 자연탐구, 미술');
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    _startDateController = TextEditingController(text: formatter.format(now));
    _endDateController = TextEditingController(
      text: formatter.format(DateTime(now.year, now.month + 4, now.day)),
    );
    // 이미 소속된 홈스쿨이 있으면 그 이름을 기본값으로 둔다(새로 만들지 않고 재사용).
    final membership = widget.controller.memberships
        .where(
          (row) => row.homeschoolId == widget.controller.selectedHomeschoolId,
        )
        .firstOrNull;
    _homeschoolController.text = membership?.homeschool.name ?? 'Nest Warm Home';
    _termController.text = '${now.year} ${now.month <= 6 ? '봄' : '가을'}학기';
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

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? '필수값입니다.' : null;

  String? _validateDate(String? value) {
    if (value == null || value.trim().isEmpty) return '필수값입니다.';
    return DateTime.tryParse(value.trim()) == null
        ? 'YYYY-MM-DD 형식으로 입력하세요.'
        : null;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final current = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null) return;
    controller.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await widget.controller.bootstrapFrame(
        homeschoolName: _homeschoolController.text,
        termName: _termController.text,
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        className: _classController.text,
        coursesCsv: _courseController.text,
      );
    } catch (_) {
      // 상태 메시지는 컨트롤러가 채워두므로 아래에서 그대로 노출한다.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.statusMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 20,
                    color: NestColors.clay,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '빠른 초기 세팅',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '학기·반·과목·시간 슬롯을 한 번에 만듭니다. 하나씩 정하고 싶다면 위 체크리스트를 따라가세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.7),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_expanded
                  ? const SizedBox(width: double.infinity)
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _homeschoolController,
                            decoration: const InputDecoration(
                              labelText: '홈스쿨 이름',
                            ),
                            validator: _validateRequired,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _termController,
                            decoration: const InputDecoration(
                              labelText: '학기 이름',
                            ),
                            validator: _validateRequired,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _startDateController,
                                  readOnly: true,
                                  onTap: () => _pickDate(_startDateController),
                                  decoration: const InputDecoration(
                                    labelText: '시작일',
                                    prefixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
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
                                  decoration: const InputDecoration(
                                    labelText: '종료일',
                                    prefixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
                                  ),
                                  validator: _validateDate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _classController,
                            decoration: const InputDecoration(
                              labelText: '반 이름',
                            ),
                            validator: _validateRequired,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _courseController,
                            decoration: const InputDecoration(
                              labelText: '기본 과목 (콤마 구분)',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton.icon(
                              onPressed: controller.isBusy ? null : _submit,
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('운영 틀 만들기'),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
