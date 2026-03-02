import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.controller});

  final NestController controller;

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
