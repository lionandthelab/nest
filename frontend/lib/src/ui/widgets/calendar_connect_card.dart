import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

/// 설정·시간표에서 Google Calendar 연결/동기화를 다룬다.
class CalendarConnectCard extends StatelessWidget {
  const CalendarConnectCard({
    super.key,
    required this.controller,
    this.childId,
  });

  final NestController controller;
  final String? childId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final connected = controller.calendarIntegration?.isConnected == true;
        final email = controller.calendarIntegration?.googleEmail;

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connected
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: connected ? NestColors.mutedSage : NestColors.clay,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google 캘린더',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  connected
                      ? '${email ?? '연결됨'} · 개인 일정과 학사일정을 오갑니다.'
                      : ' Nest 개인 일정·학사일정을 Google 캘린더에 맞출 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                if (!connected)
                  FilledButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => _connect(context),
                    child: const Text('Google 캘린더 연결'),
                  )
                else
                  Row(
                    children: [
                      if (childId != null && childId!.isNotEmpty)
                        FilledButton(
                          onPressed: controller.isBusy
                              ? null
                              : () => _sync(context),
                          child: const Text('지금 맞추기'),
                        ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: controller.isBusy
                            ? null
                            : () => controller.disconnectGoogleCalendar(),
                        child: const Text('연결 끊기'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _connect(BuildContext context) async {
    final error = await controller.connectGoogleCalendar();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Google 캘린더를 연결했습니다.')),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final error = await controller.syncGoogleCalendar(childId: childId!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? controller.statusMessage)),
    );
  }
}
