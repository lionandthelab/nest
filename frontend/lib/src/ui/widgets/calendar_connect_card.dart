import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
        final feedUrl = controller.calendarFeedUrl;
        final subscribeUrl = controller.calendarGoogleSubscribeUrl;

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
                      ? '${email ?? '연결됨'} · 학사일정·시간표·개인 일정이 연동됩니다.'
                      : 'Nest 개인 일정·학사일정·시간표를 Google 캘린더에 맞출 수 있습니다.',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: controller.isBusy
                            ? null
                            : () => _sync(context),
                        child: const Text('지금 맞추기'),
                      ),
                      if (subscribeUrl != null && subscribeUrl.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: controller.isBusy
                              ? null
                              : () => _openSubscribe(context, subscribeUrl),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Google 캘린더에 추가'),
                        ),
                      if (feedUrl != null && feedUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _copyFeedUrl(context, feedUrl),
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('구독 주소 복사'),
                        ),
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
    final error = await controller.syncGoogleCalendar(childId: childId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? controller.statusMessage)),
    );
  }

  Future<void> _openSubscribe(BuildContext context, String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 캘린더를 열 수 없습니다.')),
      );
    }
  }

  Future<void> _copyFeedUrl(BuildContext context, String feedUrl) async {
    await Clipboard.setData(ClipboardData(text: feedUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('캘린더 구독 주소(.ics)를 복사했습니다.')),
    );
  }
}
