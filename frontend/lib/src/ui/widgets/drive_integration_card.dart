import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../tabs/album/album_drive_connect_sheet.dart';
import 'nest_motion.dart';

/// 관리자 홈의 "사진 저장 위치" 카드.
///
/// 예전에는 접힌 카드 안에 루트 폴더 ID 입력란이 있었다. 관리자가 Drive에서
/// 폴더를 만들고 주소창에서 ID를 긁어 붙여 넣어야 시작되는 설정이었는데,
/// 그건 앨범을 쓰기 위한 요구로는 과했다. 지금은 상태만 보여 주고, 실제
/// 안내와 연결은 [showDriveConnectSheet]가 맡는다.
class DriveIntegrationCard extends StatefulWidget {
  const DriveIntegrationCard({
    super.key,
    required this.controller,
    this.initiallyExpanded = false,
  });

  final NestController controller;

  /// 더는 쓰이지 않는다. 카드가 접히지 않으므로 호출부 호환을 위해서만 남긴다.
  final bool initiallyExpanded;

  @override
  State<DriveIntegrationCard> createState() => _DriveIntegrationCardState();
}

class _DriveIntegrationCardState extends State<DriveIntegrationCard> {
  @override
  void initState() {
    super.initState();
    // 연결 상태 조회는 이 카드가 직접 챙긴다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.controller.isAdminLike) {
        widget.controller.loadDriveIntegration();
      }
    });
  }

  Future<void> _open() async {
    await showDriveConnectSheet(
      context: context,
      controller: widget.controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final integration = controller.driveIntegration;
    final connected = integration?.isConnected ?? false;
    final email = integration?.googleEmail;

    return Card(
      child: NestPressable(
        onPressed: _open,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: NestColors.roseMist.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_to_drive,
                  size: 20,
                  color: NestColors.clay,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '사진 저장 위치',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? (email != null && email.isNotEmpty
                                ? '$email 의 Drive에 보관 중'
                                : '관리자 Drive에 보관 중')
                          : '아직 연결하지 않았습니다. 지금은 Nest에 저장됩니다.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.72),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (controller.isLoadingDriveIntegration)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  connected ? Icons.check_circle : Icons.chevron_right_rounded,
                  size: connected ? 20 : 24,
                  color: connected
                      ? NestColors.mutedSage
                      : NestColors.deepWood.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
