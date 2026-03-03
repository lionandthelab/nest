import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class ParentHubTab extends StatelessWidget {
  const ParentHubTab({super.key, required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final sessions = controller.sessions.length;
    final gallery = controller.galleryItems.length;
    final reports = controller.openCommunityReportCount;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent Hub',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '부모 뷰에서는 우리 아이 학습 흐름과 활동 공유를 쉽게 확인할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(label: '이번 반 수업 수', value: '$sessions'),
                    _MetricCard(label: '갤러리 항목', value: '$gallery'),
                    _MetricCard(label: '미처리 신고', value: '$reports'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('부모 권장 흐름'),
                SizedBox(height: 8),
                Text('1. Timetable 탭에서 반 시간표를 확인합니다.'),
                Text('2. Gallery 탭에서 활동 사진/영상을 확인합니다.'),
                Text('3. Community 탭에서 소통하고 필요한 경우 신고합니다.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
