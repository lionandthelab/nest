import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../../widgets/nest_motion.dart';
import '../../widgets/nest_sheet.dart';

/// 관리자가 Google Drive를 연결하는 화면.
///
/// 앨범 원본이 관리자 Drive에 저장되므로, 이 연결은 "있으면 좋은 설정"이 아니라
/// 앨범을 쓰기 위한 준비다. 그래서 폴더 ID를 어디선가 찾아 붙여 넣게 하지 않고,
/// 무엇이 일어나는지 세 줄로 알린 뒤 버튼 하나로 끝낸다. 폴더는 앱이 만든다.
Future<bool?> showDriveConnectSheet({
  required BuildContext context,
  required NestController controller,
}) {
  return showNestSheet<bool>(
    context: context,
    maxWidth: 480,
    builder: (_) => _DriveConnectSheet(controller: controller),
  );
}

enum _Step { intro, connecting, done, failed }

class _DriveConnectSheet extends StatefulWidget {
  const _DriveConnectSheet({required this.controller});

  final NestController controller;

  @override
  State<_DriveConnectSheet> createState() => _DriveConnectSheetState();
}

class _DriveConnectSheetState extends State<_DriveConnectSheet> {
  late _Step _step = widget.controller.driveIntegration?.isConnected == true
      ? _Step.done
      : _Step.intro;
  String _error = '';

  bool get _isWeb => widget.controller.isWebOauthSupported;

  Future<void> _connect() async {
    setState(() {
      _step = _Step.connecting;
      _error = '';
    });

    final error = await widget.controller.connectGoogleDrive();
    if (!mounted) return;

    if (error == null) {
      NestHaptics.success();
      setState(() => _step = _Step.done);
      return;
    }
    setState(() {
      _step = _Step.failed;
      _error = error;
    });
  }

  Future<void> _disconnect() async {
    final confirmed = await showNestConfirm(
      context: context,
      title: 'Drive 연결 끊기',
      message:
          '연결을 끊으면 앞으로 올리는 사진은 Nest에 저장됩니다.\n'
          '이미 Drive에 있는 사진은 지워지지 않지만, 앨범에서는 열리지 않습니다.',
      confirmLabel: '연결 끊기',
      destructive: true,
      icon: Icons.link_off_rounded,
    );
    if (!confirmed || !mounted) return;

    final error = await widget.controller.disconnectGoogleDrive();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _step = _Step.failed;
        _error = error;
      });
      return;
    }
    setState(() => _step = _Step.intro);
  }

  Future<void> _openDrive() async {
    final folderId = widget.controller.driveIntegration?.rootFolderId;
    final url = (folderId == null || folderId.isEmpty)
        ? 'https://drive.google.com/drive/my-drive'
        : 'https://drive.google.com/drive/folders/$folderId';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return NestSheet(
      title: _titleFor(_step),
      subtitle: _subtitleFor(_step),
      icon: Icons.add_to_drive,
      iconColor: NestColors.dustyRose,
      isBusy: _step == _Step.connecting,
      showCloseButton: _step != _Step.connecting,
      actions: _actionsFor(_step),
      destructiveAction: _step == _Step.done
          ? TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('연결 끊기'),
            )
          : null,
      child: switch (_step) {
        _Step.intro => _IntroBody(isWeb: _isWeb),
        _Step.connecting => _ConnectingBody(isWeb: _isWeb),
        _Step.done => _DoneBody(
          controller: widget.controller,
          onOpenDrive: _openDrive,
        ),
        _Step.failed => _FailedBody(message: _error),
      },
    );
  }

  String _titleFor(_Step step) => switch (step) {
    _Step.intro => '사진을 어디에 보관할까요',
    _Step.connecting => '연결하는 중...',
    _Step.done => '연결됐습니다',
    _Step.failed => '연결하지 못했습니다',
  };

  String? _subtitleFor(_Step step) => switch (step) {
    _Step.intro => '관리자 Google Drive에 원본을 보관합니다.',
    _Step.connecting => null,
    _Step.done => '앨범 사진 원본이 이 계정에 쌓입니다.',
    _Step.failed => null,
  };

  List<Widget> _actionsFor(_Step step) => switch (step) {
    _Step.intro => [
      FilledButton.icon(
        onPressed: _connect,
        icon: const Icon(Icons.add_to_drive, size: 18),
        label: const Text('Google 계정으로 연결'),
      ),
    ],
    _Step.connecting => const [],
    _Step.done => [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('완료'),
      ),
    ],
    _Step.failed => [
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('닫기'),
      ),
      FilledButton(onPressed: _connect, child: const Text('다시 시도')),
    ],
  };
}

class _IntroBody extends StatelessWidget {
  const _IntroBody({required this.isWeb});

  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Bullet(
          icon: Icons.photo_library_outlined,
          title: '원본은 관리자 Drive에',
          body: '선생님과 학부모가 올린 사진 원본이 관리자 Google Drive에 저장됩니다.',
        ),
        const _Bullet(
          icon: Icons.folder_outlined,
          title: '학기·수업·날짜 폴더로 자동 정리',
          body: '폴더를 미리 만들 필요 없습니다. Nest가 알아서 만들고 넣습니다.',
        ),
        const _Bullet(
          icon: Icons.bolt_outlined,
          title: '보는 건 그대로 빠르게',
          body: '목록에 뜨는 작은 미리보기는 Nest가 갖고 있어 바로 열립니다.',
        ),
        const SizedBox(height: 6),
        _TrustNote(isWeb: isWeb),
      ],
    );
  }
}

class _TrustNote extends StatelessWidget {
  const _TrustNote({required this.isWeb});

  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: NestColors.clay),
              const SizedBox(width: 6),
              Text(
                'Nest가 접근하는 범위',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Nest가 직접 만든 파일과 폴더만 봅니다. Drive에 원래 있던 문서나 사진은 '
            '읽지 않습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isWeb
                ? 'Google 로그인 창이 뜹니다. 계정을 고르고 허용만 누르면 끝납니다.'
                : '브라우저가 열립니다. 계정을 고르고 허용한 뒤 앱으로 돌아오면 됩니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.55),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectingBody extends StatelessWidget {
  const _ConnectingBody({required this.isWeb});

  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          const _StepLine(label: 'Google 계정 확인', active: true),
          const _StepLine(label: '앨범 폴더 준비', active: true),
          const _StepLine(label: '연결 마무리', active: true),
          const SizedBox(height: 14),
          Text(
            isWeb
                ? '새 창에서 Google 로그인을 마쳐 주세요.'
                : '브라우저에서 로그인을 마친 뒤 앱으로 돌아오면 자동으로 이어집니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: active
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Icon(Icons.circle_outlined, size: 16),
          ),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.controller, required this.onOpenDrive});

  final NestController controller;
  final VoidCallback onOpenDrive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final integration = controller.driveIntegration;
    final email = integration?.googleEmail;
    final connectedAt = integration?.connectedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NestColors.mutedSage.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: NestColors.mutedSage,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (email != null && email.isNotEmpty) ? email : '연결된 계정',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (connectedAt != null)
                      Text(
                        '${DateFormat('yyyy년 M월 d일').format(connectedAt)} 연결',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _Bullet(
          icon: Icons.folder_open_outlined,
          title: '저장 위치',
          body: 'Drive의 "Nest 앨범" 폴더 아래 학기 · 수업 · 날짜 순으로 쌓입니다.',
        ),
        const _Bullet(
          icon: Icons.groups_2_outlined,
          title: '참여자 업로드',
          body: '선생님과 학부모가 올린 사진도 모두 이 계정에 저장됩니다.',
        ),
        OutlinedButton.icon(
          onPressed: onOpenDrive,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Drive에서 열어보기'),
        ),
      ],
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.isEmpty ? '잠시 후 다시 시도해 주세요.' : message,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 12),
        Text(
          '연결하지 않아도 앨범은 쓸 수 있습니다. 이 경우 사진 원본은 Nest에 저장됩니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: NestColors.deepWood.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: NestColors.roseMist.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: NestColors.clay),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
