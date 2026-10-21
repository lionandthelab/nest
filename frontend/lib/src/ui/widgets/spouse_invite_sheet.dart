import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'nest_3d_icon.dart';
import 'nest_sheet.dart';

/// 1인/가정 홈스쿨에서 엄마가 아빠를, 아빠가 엄마를 쉽게 초대하고
/// 우리 가정 보호자(+공동 관리자)로 한 번에 연결하는 시트.
Future<void> showSpouseInviteSheet({
  required BuildContext context,
  required NestController controller,
  String initialSpouseType = 'FATHER',
}) {
  return showNestSheet<void>(
    context: context,
    builder: (ctx) => _SpouseInviteSheetContent(
      controller: controller,
      initialSpouseType: initialSpouseType,
    ),
  );
}

class _SpouseInviteSheetContent extends StatefulWidget {
  const _SpouseInviteSheetContent({
    required this.controller,
    required this.initialSpouseType,
  });

  final NestController controller;
  final String initialSpouseType;

  @override
  State<_SpouseInviteSheetContent> createState() =>
      _SpouseInviteSheetContentState();
}

class _SpouseInviteSheetContentState extends State<_SpouseInviteSheetContent> {
  late String _spouseType; // 'FATHER' | 'MOTHER' | 'GUARDIAN'
  bool _grantAdminRole = true;
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    _spouseType = widget.initialSpouseType;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String get _spouseRoleLabel {
    switch (_spouseType) {
      case 'FATHER':
        return '아빠';
      case 'MOTHER':
        return '엄마';
      default:
        return '공동 양육자';
    }
  }

  String get _inviterLabel {
    switch (_spouseType) {
      case 'FATHER':
        return '엄마가 아빠 초대';
      case 'MOTHER':
        return '아빠가 엄마 초대';
      default:
        return '가족 보호자 초대';
    }
  }

  String _buildInviteMessage(String homeschoolName, String code) {
    return '[Nest 우리집 홈스쿨 초대장 💌]\n'
        '여보! 우리 아이 홈스쿨링 공간 \'$homeschoolName\'을 만들었어.\n'
        '아래 순서대로 30초 만에 합류해 줘!\n\n'
        '1️⃣ Nest 앱 또는 웹(https://nestapp.life) 접속 후 로그인\n'
        '2️⃣ [참여 코드로 합류]에서 코드 [$code] 입력\n'
        '3️⃣ 역할은 [학부모] 선택해서 요청 보내기!';
  }

  void _setFeedback(String message) {
    if (!mounted) return;
    setState(() => _feedbackMessage = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyInviteMessage(String homeschoolName, String code) async {
    final text = _buildInviteMessage(homeschoolName, code);
    await Clipboard.setData(ClipboardData(text: text));
    _setFeedback('$_spouseRoleLabel에게 보낼 초대 문구를 복사했어요! 카톡이나 문자에 붙여넣어 보내세요.');
  }

  Future<void> _copyCodeOnly(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _setFeedback('참여 코드($code)를 복사했어요.');
  }

  Future<void> _ensureJoinCode() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await widget.controller.rotateJoinCode();
      _setFeedback('참여 코드($code)가 준비되었어요.');
    } catch (e) {
      _setFeedback(
        e is StateError ? e.message : widget.controller.statusMessage,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendEmailInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setFeedback('$_spouseRoleLabel의 이메일 주소를 입력해 주세요.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.inviteSpouseByEmail(
        email: email,
        guardianType: _spouseType,
        grantAdminRole: _grantAdminRole,
      );
      _emailController.clear();
      _setFeedback(widget.controller.statusMessage);
    } catch (e) {
      _setFeedback(
        e is StateError ? e.message : widget.controller.statusMessage,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectCandidate({
    required String userId,
    String? joinRequestId,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.connectSpouseToMyFamily(
        spouseUserId: userId,
        guardianType: _spouseType,
        joinRequestId: joinRequestId,
        grantAdminRole: _grantAdminRole,
      );
      _setFeedback(widget.controller.statusMessage);
    } catch (e) {
      _setFeedback(
        e is StateError ? e.message : widget.controller.statusMessage,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final homeschoolName = controller.selectedHomeschoolName.isEmpty
        ? '우리집 홈스쿨'
        : controller.selectedHomeschoolName;
    final joinCode = controller.selectedHomeschoolJoinCode?.trim() ?? '';
    final hasCode = joinCode.isNotEmpty;

    final myUserId = controller.user?.id ?? '';
    final existingFamilyGuardians = controller.families.isEmpty
        ? const <String>{}
        : (controller.familyGuardianUserIdsByFamily[controller
                      .families
                      .first
                      .id] ??
                  const <String>[])
              .toSet();

    final pendingRequests = controller.joinRequests
        .where((r) => r.isPending && r.requesterUserId != myUserId)
        .toList();

    final unlinkedMemberIds = controller.membershipUserIds
        .where(
          (uid) => uid != myUserId && !existingFamilyGuardians.contains(uid),
        )
        .toList();

    return NestSheet(
      title: '엄마·아빠 함께하기 (배우자 초대)',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Nest3dIcon.family(size: 40, floating: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '엄마면 아빠, 아빠면 엄마를 초대해 아이의 시간표와 학습 기록을 함께 관리해 보세요.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '1. 누구를 초대할까요?',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.face_6_outlined, size: 18),
                label: const Text('아빠 초대하기 (엄마가 초대)'),
                selected: _spouseType == 'FATHER',
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _spouseType = 'FATHER'),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.face_3_outlined, size: 18),
                label: const Text('엄마 초대하기 (아빠가 초대)'),
                selected: _spouseType == 'MOTHER',
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _spouseType = 'MOTHER'),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.family_restroom_outlined, size: 18),
                label: const Text('공동 양육자 초대'),
                selected: _spouseType == 'GUARDIAN',
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _spouseType = 'GUARDIAN'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _grantAdminRole,
            onChanged: _busy
                ? null
                : (val) => setState(() => _grantAdminRole = val ?? true),
            title: Text(
              '$_spouseRoleLabel에게 공동 관리자(시간표·과목 함께 편집) 권한도 드리기',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (pendingRequests.isNotEmpty || unlinkedMemberIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NestColors.mutedSage.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: NestColors.mutedSage.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '참여 요청·합류 대기 중인 가족을 바로 $_spouseRoleLabel로 연결하세요!',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final req in pendingRequests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${req.requesterName ?? req.requesterEmail} (가입 요청)',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy
                                ? null
                                : () => _connectCandidate(
                                    userId: req.requesterUserId,
                                    joinRequestId: req.id,
                                  ),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text('$_spouseRoleLabel로 승인·연결'),
                          ),
                        ],
                      ),
                    ),
                  for (final uid in unlinkedMemberIds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              controller.findMemberDisplayName(uid),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy
                                ? null
                                : () => _connectCandidate(userId: uid),
                            icon: const Icon(Icons.link, size: 18),
                            label: Text('$_spouseRoleLabel로 바로 연결'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '2. 카톡·문자로 초대장 보내기 (가장 쉬워요)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NestColors.creamyWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NestColors.roseMist),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: NestColors.roseMist.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _inviterLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: NestColors.deepWood,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasCode ? '참여 코드: $joinCode' : '참여 코드 미발급',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: NestColors.clay,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (hasCode)
                  Text(
                    _buildInviteMessage(homeschoolName, joinCode),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.84),
                      height: 1.45,
                    ),
                  )
                else
                  Text(
                    '참여 코드를 발급하면 카톡·문자로 바로 보낼 수 있는 초대 문구가 만들어져요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.72),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasCode) ...[
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _copyInviteMessage(
                                homeschoolName,
                                joinCode,
                              ),
                        icon: const Icon(Icons.copy_all_outlined, size: 18),
                        label: Text('$_spouseRoleLabel 초대 문구 복사하기'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _copyCodeOnly(joinCode),
                        icon: const Icon(Icons.vpn_key_outlined, size: 18),
                        label: const Text('코드만 복사'),
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: _busy ? null : _ensureJoinCode,
                        icon: const Icon(Icons.vpn_key_outlined, size: 18),
                        label: const Text('참여 코드 발급하기'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '3. 이메일로 직접 초대장 보내기 (선택)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$_spouseRoleLabel의 이메일을 입력하면 로그인 즉시 홈스쿨 초대를 수락할 수 있어요.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: '$_spouseRoleLabel 이메일 주소',
                    hintText: 'spouse@example.com',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendEmailInvite(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _sendEmailInvite,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('초대 발송'),
              ),
            ],
          ),
          if (_feedbackMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _feedbackMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.clay,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 1인 홈스쿨에서 배우자(엄마/아빠)가 아직 연결되지 않았을 때 보여주는 친절한 배너 카드.
class SpouseInviteBannerCard extends StatelessWidget {
  const SpouseInviteBannerCard({
    super.key,
    required this.controller,
  });

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Nest3dIcon.family(size: 36, floating: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '엄마·아빠 함께 홈스쿨 운영하기',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '엄마면 아빠, 아빠면 엄마를 초대해 시간표와 기록을 함께 보세요.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => showSpouseInviteSheet(
                    context: context,
                    controller: controller,
                    initialSpouseType: 'FATHER',
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('아빠 초대하기'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => showSpouseInviteSheet(
                    context: context,
                    controller: controller,
                    initialSpouseType: 'MOTHER',
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('엄마 초대하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
