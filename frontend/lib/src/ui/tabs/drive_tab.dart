import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';

class DriveTab extends StatefulWidget {
  const DriveTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends State<DriveTab> {
  final _rootFolderController = TextEditingController();
  final _accessTokenController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  final _tokenExpiresAtController = TextEditingController();

  String _folderPolicy = 'TERM_CLASS_DATE';
  String? _lastSyncIntegrationId;
  bool _showDeveloperFields = false;

  @override
  void dispose() {
    _rootFolderController.dispose();
    _accessTokenController.dispose();
    _refreshTokenController.dispose();
    _tokenExpiresAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncFromController();

    final controller = widget.controller;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Google Drive 연동',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Tooltip(
                      richMessage: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Google Drive 연동 설정법\n\n',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text: '1. Google Cloud Console에서 OAuth 2.0 클라이언트를 생성합니다.\n'
                                '2. 승인된 리디렉션 URI에 아래 주소를 추가합니다:\n'
                                '   (배포 주소)/oauth/google/callback.html\n'
                                '3. Supabase Edge Function 시크릿에 다음을 설정합니다:\n'
                                '   • GOOGLE_CLIENT_ID\n'
                                '   • GOOGLE_CLIENT_SECRET\n'
                                '   • GOOGLE_REDIRECT_URI\n'
                                '4. 아래 "OAuth 연결 시작" 버튼을 누르면 Google 로그인 팝업이 열립니다.\n'
                                '5. 권한 허용 후 "OAuth 동기화"를 눌러 연동을 완료합니다.\n\n'
                                '루트 폴더 ID는 Google Drive에서 사용할 상위 폴더의 ID입니다.\n'
                                '(Drive 폴더 URL의 마지막 경로 값)',
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.info_outline, size: 20),
                        color: NestColors.clay,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'OAuth 연결 후 폴더 정책을 설정하면 미디어 업로드가 자동으로 Drive에 저장됩니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isBusy ? null : _startOauth,
                      icon: const Icon(Icons.link),
                      label: const Text('OAuth 연결 시작'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : _syncOauth,
                      icon: const Icon(Icons.sync),
                      label: const Text('OAuth 동기화'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : _reloadDrive,
                      icon: const Icon(Icons.refresh),
                      label: const Text('상태 갱신'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _rootFolderController,
                  decoration: const InputDecoration(
                    labelText: '루트 폴더 ID',
                    hintText: 'Google Drive 폴더 URL의 마지막 경로 값',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _folderPolicy,
                  decoration: const InputDecoration(labelText: '폴더 정책'),
                  items: const [
                    DropdownMenuItem(
                      value: 'TERM_CLASS_DATE',
                      child: Text('학기 > 반 > 날짜별 정리'),
                    ),
                    DropdownMenuItem(
                      value: 'CLASS_CHILD_DATE',
                      child: Text('반 > 아이 > 날짜별 정리'),
                    ),
                  ],
                  onChanged: controller.isBusy
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _folderPolicy = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: controller.isBusy
                        ? null
                        : () {
                            setState(() {
                              _showDeveloperFields = !_showDeveloperFields;
                            });
                          },
                    icon: Icon(
                      _showDeveloperFields
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    label: Text(
                      _showDeveloperFields ? '개발자 고급 설정 숨기기' : '개발자 고급 설정 보기',
                    ),
                  ),
                ),
                if (_showDeveloperFields) ...[
                  TextField(
                    controller: _accessTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Access Token (선택)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _refreshTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Refresh Token (선택)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenExpiresAtController,
                    decoration: const InputDecoration(
                      labelText: 'Token Expires At ISO (선택)',
                      hintText: '2026-03-02T19:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isBusy ? null : _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('설정 저장'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : _disconnect,
                      icon: const Icon(Icons.link_off),
                      label: const Text('연동 해제'),
                    ),
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
              children: [
                Text('연동 상태', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                if (controller.driveIntegration == null)
                  const NestEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: '연동 정보 없음',
                    subtitle: 'OAuth 시작 버튼으로 Google Drive를 연결하세요.',
                  )
                else
                  _DriveStatusView(controller: controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _syncFromController() {
    final integration = widget.controller.driveIntegration;
    if (integration == null) {
      return;
    }

    final shouldSync = _lastSyncIntegrationId != integration.id;
    if (!shouldSync) {
      return;
    }

    _lastSyncIntegrationId = integration.id;
    _rootFolderController.text = integration.rootFolderId ?? '';
    _folderPolicy = integration.folderPolicy ?? 'TERM_CLASS_DATE';
    _accessTokenController.text = integration.googleAccessToken ?? '';
    _refreshTokenController.text = integration.googleRefreshToken ?? '';

    if (integration.googleTokenExpiresAt != null) {
      _tokenExpiresAtController.text = integration.googleTokenExpiresAt!
          .toUtc()
          .toIso8601String();
    } else {
      _tokenExpiresAtController.text = '';
    }
  }

  Future<void> _startOauth() async {
    try {
      await widget.controller.startDriveOauth(
        rootFolderId: _rootFolderController.text,
        folderPolicy: _folderPolicy,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _syncOauth() async {
    try {
      await widget.controller.syncOauthResult();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _reloadDrive() async {
    try {
      await widget.controller.loadDriveIntegration();
      _showMessage('Drive 상태를 갱신했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await widget.controller.saveDriveSettings(
        rootFolderId: _rootFolderController.text,
        folderPolicy: _folderPolicy,
        accessToken: _accessTokenController.text,
        refreshToken: _refreshTokenController.text,
        tokenExpiresAt: _tokenExpiresAtController.text,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.controller.disconnectDrive();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

String _driveStatusLabel(String status) {
  return switch (status) {
    'CONNECTED' => '연결됨',
    'DISCONNECTED' => '연결 안 됨',
    'ERROR' => '오류',
    _ => status,
  };
}

String _folderPolicyLabel(String? policy) {
  return switch (policy) {
    'TERM_CLASS_DATE' => '학기 > 반 > 날짜별 정리',
    'CLASS_CHILD_DATE' => '반 > 아이 > 날짜별 정리',
    _ => '-',
  };
}

class _DriveStatusView extends StatelessWidget {
  const _DriveStatusView({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final integration = controller.driveIntegration;
    if (integration == null) {
      return const SizedBox.shrink();
    }

    final connectedAt = integration.connectedAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(integration.connectedAt!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('연동 상태: ${_driveStatusLabel(integration.status)}'),
          const SizedBox(height: 4),
          Text('루트 폴더 ID: ${integration.rootFolderId ?? '-'}'),
          const SizedBox(height: 4),
          Text('폴더 정책: ${_folderPolicyLabel(integration.folderPolicy)}'),
          const SizedBox(height: 4),
          Text('연결 일시: $connectedAt'),
          const SizedBox(height: 4),
          Text('액세스 토큰: ${integration.hasAccessToken ? '있음' : '없음'}'),
          const SizedBox(height: 4),
          Text('리프레시 토큰: ${integration.hasRefreshToken ? '있음' : '없음'}'),
          if (integration.googleTokenExpiresAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '토큰 만료: ${DateFormat('yyyy-MM-dd HH:mm').format(integration.googleTokenExpiresAt!)}',
              ),
            ),
        ],
      ),
    );
  }
}
