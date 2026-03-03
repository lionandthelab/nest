import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class TeacherHubTab extends StatelessWidget {
  const TeacherHubTab({super.key, required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final sessions = controller.sessions.length;
    final proposals = controller.proposals.length;
    final gallery = controller.galleryItems.length;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher Hub',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '교사 뷰에서는 수업 운영, 반 활동 기록, 커뮤니티 소통을 중심으로 사용합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(label: '배정 수업 수', value: '$sessions'),
                    _MetricCard(label: '생성안 수', value: '$proposals'),
                    _MetricCard(label: '갤러리 항목', value: '$gallery'),
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
                Text('교사 권장 흐름'),
                SizedBox(height: 8),
                Text('1. Timetable 탭에서 수업 배치를 확인합니다.'),
                Text('2. Gallery 탭에서 수업 활동 사진/영상을 업로드합니다.'),
                Text('3. Community 탭에서 학부모와 공지/소통을 진행합니다.'),
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
