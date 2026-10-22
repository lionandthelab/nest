import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'announcement_attachments.dart';
import 'entity_visuals.dart';
import 'nest_3d_icon.dart';
import 'nest_empty_state.dart';
import 'nest_sheet.dart';
import 'search_select_field.dart';

/// 홈스쿨 실시간 채팅 화면.
///
/// - 전체 단톡방 / 반별 단톡방 / 1:1 대화 전환
/// - 실시간 메시지 수신(Supabase Realtime) 및 즉시 푸시 알림(FCM, `nest-notify`)
/// - 사진·동영상·문서 파일·스케줄(시간표/학사일정/직접 입력)·연락처(구성원/교사/직접 입력) 원클릭 공유
class HomeschoolChatView extends StatefulWidget {
  const HomeschoolChatView({
    super.key,
    required this.controller,
    this.initialClassGroupId,
    this.initialRecipientUserId,
  });

  final NestController controller;
  final String? initialClassGroupId;
  final String? initialRecipientUserId;

  @override
  State<HomeschoolChatView> createState() => _HomeschoolChatViewState();
}

class _HomeschoolChatViewState extends State<HomeschoolChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedClassGroupId;
  String? _selectedRecipientUserId;
  String? _selectedRecipientName;
  final List<PendingMediaFile> _pendingFiles = [];
  int _lastRenderedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedClassGroupId = widget.initialClassGroupId;
    _selectedRecipientUserId = widget.initialRecipientUserId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.markChatRead();
      unawaited(widget.controller.ensureChatMessages());
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<HomeschoolChatMessage> _filteredMessages(NestController controller) {
    final myUserId = controller.user?.id ?? '';
    return controller.chatMessages.where((msg) {
      if (_selectedRecipientUserId != null &&
          _selectedRecipientUserId!.isNotEmpty) {
        final target = _selectedRecipientUserId!;
        return msg.isDirectMessage &&
            ((msg.senderUserId == myUserId && msg.recipientUserId == target) ||
                (msg.senderUserId == target && msg.recipientUserId == myUserId));
      }
      if (_selectedClassGroupId != null &&
          _selectedClassGroupId!.isNotEmpty) {
        return msg.isClassRoom && msg.classGroupId == _selectedClassGroupId;
      }
      return msg.isGeneralRoom;
    }).toList();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showSnack(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleSendTextAndFiles() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingFiles.isEmpty) return;

    final filesToSend = List<PendingMediaFile>.from(_pendingFiles);
    _textController.clear();
    setState(() {
      _pendingFiles.clear();
    });

    try {
      await widget.controller.sendChatMessage(
        content: text,
        classGroupId: _selectedClassGroupId,
        recipientUserId: _selectedRecipientUserId,
        files: filesToSend,
      );
      _scrollToBottomSoon();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingFiles.addAll(filesToSend);
      });
      _showSnack(
        error is StateError ? error.message : '메시지 전송에 실패했습니다: $error',
      );
    }
  }

  Future<void> _pickImages() async {
    try {
      final picked = await widget.controller.pickChatImages();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _pendingFiles.addAll(picked);
      });
    } catch (error) {
      _showSnack('사진 선택 중 오류가 발생했습니다: $error');
    }
  }

  Future<void> _pickVideos() async {
    try {
      final picked = await widget.controller.pickChatVideos();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _pendingFiles.addAll(picked);
      });
    } catch (error) {
      _showSnack('동영상 선택 중 오류가 발생했습니다: $error');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final picked = await widget.controller.pickChatFiles();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _pendingFiles.addAll(picked);
      });
    } catch (error) {
      _showSnack('파일 선택 중 오류가 발생했습니다: $error');
    }
  }

  Future<void> _selectDirectMessageTarget(NestController controller) async {
    final myUserId = controller.user?.id ?? '';
    final options = <SelectSheetOption<String>>[];
    final seenUserIds = <String>{};

    for (final entry in controller.homeschoolMemberDirectory) {
      if (entry.userId.isEmpty ||
          entry.userId == myUserId ||
          seenUserIds.contains(entry.userId)) {
        continue;
      }
      seenUserIds.add(entry.userId);
      final name = entry.fullName.trim().isNotEmpty
          ? entry.fullName.trim()
          : entry.displayLabel;
      options.add(
        SelectSheetOption<String>(
          value: entry.userId,
          title: name,
          subtitle: entry.email.isNotEmpty ? entry.email : '홈스쿨 구성원',
          keywords: '$name ${entry.email}',
        ),
      );
    }

    for (final teacher in controller.teacherProfiles) {
      final uid = teacher.userId ?? '';
      if (uid.isEmpty || uid == myUserId || seenUserIds.contains(uid)) {
        continue;
      }
      seenUserIds.add(uid);
      options.add(
        SelectSheetOption<String>(
          value: uid,
          title: teacher.displayName,
          subtitle: '선생님',
          keywords: teacher.displayName,
        ),
      );
    }

    for (final member in controller.homeschoolMemberships) {
      final uid = member.userId;
      if (uid.isEmpty || uid == myUserId || seenUserIds.contains(uid)) {
        continue;
      }
      seenUserIds.add(uid);
      final name = controller.findMemberName(uid).isNotEmpty
          ? controller.findMemberName(uid)
          : controller.parentCandidateLabel(uid);
      options.add(
        SelectSheetOption<String>(
          value: uid,
          title: name,
          subtitle: '홈스쿨 구성원',
          keywords: name,
        ),
      );
    }

    if (options.isEmpty) {
      _showSnack('아직 1:1 대화를 나눌 다른 홈스쿨 구성원이 없습니다.');
      return;
    }

    final chosen = await showSelectSheet<String>(
      context: context,
      title: '1:1 대화 상대 선택',
      helpText: '선택한 구성원과 1:1 실시간 채팅 및 푸시 알림을 주고받습니다.',
      options: options,
      currentValue: _selectedRecipientUserId,
    );

    if (!mounted || chosen == null || chosen.isEmpty) return;
    final match = options.where((o) => o.value == chosen).firstOrNull;
    setState(() {
      _selectedClassGroupId = null;
      _selectedRecipientUserId = chosen;
      _selectedRecipientName = match?.title ?? controller.findMemberName(chosen);
    });
    _scrollToBottomSoon();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = _filteredMessages(controller);
        if (messages.length != _lastRenderedMessageCount) {
          _lastRenderedMessageCount = messages.length;
          _scrollToBottomSoon();
        }

        return Column(
          children: [
            _buildChannelHeader(context, controller),
            Expanded(
              child: controller.isLoadingChat && controller.chatMessages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                  ? _buildEmptyChatState(context, controller)
                  : RefreshIndicator(
                      onRefresh: controller.refreshChatMessages,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final prev = index > 0 ? messages[index - 1] : null;
                          final showDateHeader = _shouldShowDateDivider(
                            prev?.createdAt,
                            message.createdAt,
                          );
                          final isMine =
                              message.senderUserId == controller.user?.id;
                          final canDelete = isMine || controller.isAdminLike;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDateHeader && message.createdAt != null)
                                _DateDividerPill(
                                  date: message.createdAt!.toLocal(),
                                ),
                              _ChatMessageBubble(
                                message: message,
                                isMine: isMine,
                                canDelete: canDelete,
                                onDelete: () => _confirmDelete(message),
                                onSaveScheduleToPersonal:
                                    message.sharedSchedule == null
                                    ? null
                                    : () => _saveSharedScheduleToMyCalendar(
                                        message.sharedSchedule!,
                                      ),
                                onOpenUrl: _openExternalUrl,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
            _buildComposerArea(context, controller),
          ],
        );
      },
    );
  }

  Widget _buildChannelHeader(BuildContext context, NestController controller) {
    final theme = Theme.of(context);
    final classGroups = controller.classGroups;
    final isGeneral =
        (_selectedClassGroupId == null || _selectedClassGroupId!.isEmpty) &&
        (_selectedRecipientUserId == null || _selectedRecipientUserId!.isEmpty);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: NestColors.roseMist.withValues(alpha: 0.85),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  key: const ValueKey('chat-room-all'),
                  selected: isGeneral,
                  avatar: const Icon(Icons.forum_outlined, size: 16),
                  label: const Text('전체 단톡방'),
                  onSelected: (_) {
                    setState(() {
                      _selectedClassGroupId = null;
                      _selectedRecipientUserId = null;
                      _selectedRecipientName = null;
                    });
                    _scrollToBottomSoon();
                  },
                ),
                for (final group in classGroups) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    key: ValueKey('chat-room-class-${group.id}'),
                    selected:
                        _selectedRecipientUserId == null &&
                        _selectedClassGroupId == group.id,
                    avatar: const Icon(Icons.groups_2_outlined, size: 16),
                    label: Text(group.name),
                    onSelected: (_) {
                      setState(() {
                        _selectedClassGroupId = group.id;
                        _selectedRecipientUserId = null;
                        _selectedRecipientName = null;
                      });
                      _scrollToBottomSoon();
                    },
                  ),
                ],
                const SizedBox(width: 6),
                ActionChip(
                  key: const ValueKey('chat-room-dm'),
                  avatar: Icon(
                    Icons.person_pin_circle_outlined,
                    size: 16,
                    color: _selectedRecipientUserId != null
                        ? NestColors.deepWood
                        : NestColors.clay,
                  ),
                  backgroundColor: _selectedRecipientUserId != null
                      ? NestColors.dustyRose.withValues(alpha: 0.25)
                      : null,
                  label: Text(
                    _selectedRecipientUserId != null
                        ? '1:1 · ${_selectedRecipientName ?? '대화 중'}'
                        : '1:1 대화',
                  ),
                  onPressed: () => _selectDirectMessageTarget(controller),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '새로고침',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.isLoadingChat
                      ? null
                      : controller.refreshChatMessages,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 14,
                color: NestColors.mutedSage,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _selectedRecipientUserId != null
                      ? '${_selectedRecipientName ?? '상대방'}님에게 즉시 푸시 알림이 전송됩니다'
                      : _selectedClassGroupId != null
                      ? '${controller.findClassGroupName(_selectedClassGroupId)} 구성원에게 실시간 푸시 알림이 전송됩니다'
                      : '메시지·사진·동영상·스케줄·연락처 전송 시 홈스쿨 구성원에게 푸시 알림이 전송됩니다',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.68),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState(BuildContext context, NestController controller) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      children: [
        NestEmptyState.with3d(
          illustration: const Nest3dIcon.community(size: 72, floating: true),
          title: '첫 대화를 시작해 보세요',
          subtitle:
              '메시지뿐 아니라 사진·동영상·수업 스케줄·연락처도 아래 버튼으로 손쉽게 공유할 수 있어요.',
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openShareScheduleSheet(controller),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('스케줄 공유하기'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openShareContactSheet(controller),
              icon: const Icon(Icons.contact_phone_outlined, size: 18),
              label: const Text('연락처 공유하기'),
            ),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('사진·동영상 보내기'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComposerArea(BuildContext context, NestController controller) {
    final isSending = controller.isSendingChatMessage;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: NestColors.deepWood.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: NestColors.roseMist.withValues(alpha: 0.9),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 원클릭 공유 액션 바 (사진 · 동영상 · 스케줄 · 연락처 · 파일) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickShareChip(
                  key: const ValueKey('chat-share-photo'),
                  icon: Icons.photo_outlined,
                  label: '사진',
                  onTap: isSending ? null : _pickImages,
                ),
                const SizedBox(width: 6),
                _QuickShareChip(
                  key: const ValueKey('chat-share-video'),
                  icon: Icons.videocam_outlined,
                  label: '동영상',
                  onTap: isSending ? null : _pickVideos,
                ),
                const SizedBox(width: 6),
                _QuickShareChip(
                  key: const ValueKey('chat-share-schedule'),
                  icon: Icons.event_available_outlined,
                  label: '스케줄 공유',
                  accent: true,
                  onTap: isSending
                      ? null
                      : () => _openShareScheduleSheet(controller),
                ),
                const SizedBox(width: 6),
                _QuickShareChip(
                  key: const ValueKey('chat-share-contact'),
                  icon: Icons.contact_phone_outlined,
                  label: '연락처 공유',
                  accent: true,
                  onTap: isSending
                      ? null
                      : () => _openShareContactSheet(controller),
                ),
                const SizedBox(width: 6),
                _QuickShareChip(
                  key: const ValueKey('chat-share-file'),
                  icon: Icons.attach_file_outlined,
                  label: '파일',
                  onTap: isSending ? null : _pickFiles,
                ),
              ],
            ),
          ),
          if (_pendingFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final file = _pendingFiles[index];
                  final isVideo = file.mimeType.startsWith('video/');
                  final isImage = file.mimeType.startsWith('image/');
                  return InputChip(
                    avatar: Icon(
                      isVideo
                          ? Icons.videocam
                          : isImage
                          ? Icons.image
                          : Icons.insert_drive_file,
                      size: 16,
                      color: NestColors.deepWood,
                    ),
                    label: Text(
                      '${file.name} (${formatAttachmentSize(file.bytes.length)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () {
                      setState(() {
                        _pendingFiles.removeAt(index);
                      });
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chat-message-input'),
                  controller: _textController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSendTextAndFiles(),
                  decoration: InputDecoration(
                    hintText: _pendingFiles.isNotEmpty
                        ? '첨부 파일과 함께 보낼 메시지를 입력하세요 (선택)'
                        : '메시지를 입력하세요...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    filled: true,
                    fillColor: NestColors.creamyWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: NestColors.roseMist.withValues(alpha: 0.9),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: NestColors.roseMist.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('chat-send-button'),
                onPressed: isSending ? null : _handleSendTextAndFiles,
                style: FilledButton.styleFrom(
                  backgroundColor: NestColors.dustyRose,
                  foregroundColor: NestColors.deepWood,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 스케줄 공유 시트 (시간표 수업 · 학사/개인 일정 · 직접 입력) ──

  Future<void> _openShareScheduleSheet(NestController controller) async {
    final shared = await showNestSheet<SharedScheduleInfo>(
      context: context,
      builder: (context) => _ShareScheduleSheet(controller: controller),
    );
    if (!mounted || shared == null) return;

    try {
      await controller.sendScheduleChatMessage(
        schedule: shared,
        classGroupId: _selectedClassGroupId,
        recipientUserId: _selectedRecipientUserId,
      );
      _scrollToBottomSoon();
    } catch (error) {
      _showSnack(
        error is StateError ? error.message : '스케줄 공유에 실패했습니다: $error',
      );
    }
  }

  // ── 연락처 공유 시트 (구성원/교사 선택 · 직접 입력) ──

  Future<void> _openShareContactSheet(NestController controller) async {
    final shared = await showNestSheet<SharedContactInfo>(
      context: context,
      builder: (context) => _ShareContactSheet(controller: controller),
    );
    if (!mounted || shared == null) return;

    try {
      await controller.sendContactChatMessage(
        contact: shared,
        classGroupId: _selectedClassGroupId,
        recipientUserId: _selectedRecipientUserId,
      );
      _scrollToBottomSoon();
    } catch (error) {
      _showSnack(
        error is StateError ? error.message : '연락처 공유에 실패했습니다: $error',
      );
    }
  }

  Future<void> _saveSharedScheduleToMyCalendar(
    SharedScheduleInfo schedule,
  ) async {
    final controller = widget.controller;
    DateTime targetDate = DateTime.now();
    if (schedule.date.isNotEmpty) {
      final parsed = DateTime.tryParse(schedule.date);
      if (parsed != null) targetDate = parsed;
    }

    int startHour = 9;
    int startMin = 0;
    int endHour = 10;
    int endMin = 0;
    if (schedule.timeRange.contains('-')) {
      final parts = schedule.timeRange.split('-');
      if (parts.length == 2) {
        final sParts = parts[0].trim().split(':');
        final eParts = parts[1].trim().split(':');
        if (sParts.length >= 2) {
          startHour = int.tryParse(sParts[0]) ?? 9;
          startMin = int.tryParse(sParts[1]) ?? 0;
        }
        if (eParts.length >= 2) {
          endHour = int.tryParse(eParts[0]) ?? (startHour + 1);
          endMin = int.tryParse(eParts[1]) ?? startMin;
        }
      }
    }

    var startsAt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      startHour,
      startMin,
    );
    var endsAt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      endHour,
      endMin,
    );
    if (!endsAt.isAfter(startsAt)) {
      endsAt = startsAt.add(const Duration(hours: 1));
    }

    final notesText = [
      if (schedule.className.isNotEmpty) '반: ${schedule.className}',
      if (schedule.teacherName.isNotEmpty) '담당: ${schedule.teacherName}',
      if (schedule.location.isNotEmpty) '장소: ${schedule.location}',
      if (schedule.note.isNotEmpty) schedule.note,
    ].join(' · ');

    final childId =
        controller.activeStudentChildId ??
        controller.myChildren.firstOrNull?.id ??
        controller.children.firstOrNull?.id ??
        '';

    try {
      if (childId.isNotEmpty) {
        await controller.createPersonalEvent(
          childId: childId,
          title: schedule.title,
          notes: notesText,
          startsAt: startsAt,
          endsAt: endsAt,
        );
      } else if (controller.isAdminLike) {
        await controller.createAcademicEvent(
          title: schedule.title,
          description: notesText,
          eventDate: DateFormat('yyyy-MM-dd').format(targetDate),
          publishAnnouncement: false,
        );
      } else {
        throw StateError('일정을 연결할 자녀 정보가 없습니다.');
      }
      _showSnack('"${schedule.title}" 일정을 내 일정에 담았습니다.');
    } catch (error) {
      _showSnack('내 일정 추가 실패: $error');
    }
  }

  Future<void> _confirmDelete(HomeschoolChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 채팅 메시지를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.deleteChatMessage(message);
    } catch (error) {
      _showSnack('메시지 삭제 실패: $error');
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _shouldShowDateDivider(DateTime? prev, DateTime? curr) {
    if (curr == null) return false;
    if (prev == null) return true;
    final p = prev.toLocal();
    final c = curr.toLocal();
    return p.year != c.year || p.month != c.month || p.day != c.day;
  }
}

class _QuickShareChip extends StatelessWidget {
  const _QuickShareChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent
              ? NestColors.roseMist.withValues(alpha: 0.72)
              : NestColors.creamyWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent
                ? NestColors.dustyRose.withValues(alpha: 0.7)
                : NestColors.roseMist,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: NestColors.deepWood),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: NestColors.deepWood,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDividerPill extends StatelessWidget {
  const _DateDividerPill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: NestColors.roseMist.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.canDelete,
    required this.onDelete,
    required this.onSaveScheduleToPersonal,
    required this.onOpenUrl,
  });

  final HomeschoolChatMessage message;
  final bool isMine;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback? onSaveScheduleToPersonal;
  final Future<void> Function(String url) onOpenUrl;

  String _roleLabel(String raw) {
    return switch (raw) {
      'HOMESCHOOL_ADMIN' => '관리자',
      'STAFF' => '스태프',
      'TEACHER' => '선생님',
      'GUEST_TEACHER' => '초빙교사',
      'PARENT' => '학부모',
      'STUDENT' => '학생',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = message.createdAt == null
        ? ''
        : DateFormat('a h:mm', 'ko_KR').format(message.createdAt!.toLocal());
    final roleBadge = _roleLabel(message.senderRole);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            EntityAvatar(
              label: message.senderName.isNotEmpty ? message.senderName : '구',
              size: 34,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.senderName.isNotEmpty
                              ? message.senderName
                              : '구성원',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: NestColors.deepWood,
                          ),
                        ),
                        if (roleBadge.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: NestColors.roseMist,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              roleBadge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: NestColors.clay,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMine
                          ? NestColors.dustyRose.withValues(alpha: 0.28)
                          : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMine ? 18 : 6),
                        topRight: Radius.circular(isMine ? 6 : 18),
                        bottomLeft: const Radius.circular(18),
                        bottomRight: const Radius.circular(18),
                      ),
                      border: Border.all(
                        color: isMine
                            ? NestColors.dustyRose.withValues(alpha: 0.65)
                            : NestColors.roseMist,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.sharedSchedule != null)
                          _SharedScheduleCard(
                            schedule: message.sharedSchedule!,
                            onSaveToMyCalendar: onSaveScheduleToPersonal,
                          ),
                        if (message.sharedContact != null)
                          _SharedContactCard(
                            contact: message.sharedContact!,
                            onOpenUrl: onOpenUrl,
                          ),
                        if (message.attachments.isNotEmpty)
                          _ChatAttachmentsSection(
                            attachments: message.attachments,
                            onOpenUrl: onOpenUrl,
                          ),
                        if (message.content.isNotEmpty &&
                            message.messageType != 'SCHEDULE' &&
                            message.messageType != 'CONTACT') ...[
                          if (message.attachments.isNotEmpty)
                            const SizedBox(height: 8),
                          SelectableText(
                            message.content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: NestColors.deepWood,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: NestColors.deepWood.withValues(alpha: 0.55),
                        ),
                      ),
                    if (canDelete) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onDelete,
                        child: Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: NestColors.deepWood.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAttachmentsSection extends StatelessWidget {
  const _ChatAttachmentsSection({
    required this.attachments,
    required this.onOpenUrl,
  });

  final List<ChatAttachment> attachments;
  final Future<void> Function(String url) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a.isImage).toList();
    final videos = attachments.where((a) => a.isVideo).toList();
    final files = attachments.where((a) => !a.isImage && !a.isVideo).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: images.map((img) {
              return GestureDetector(
                onTap: () => _showImageDialog(context, img),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    img.publicUrl,
                    width: images.length == 1 ? 240 : 112,
                    height: images.length == 1 ? 180 : 112,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 160,
                      height: 100,
                      color: NestColors.roseMist,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        for (final video in videos) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => onOpenUrl(video.publicUrl),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NestColors.deepWood.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NestColors.roseMist),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: NestColors.dustyRose,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '동영상 재생 · ${formatAttachmentSize(video.sizeBytes)}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: NestColors.clay,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        for (final file in files) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => onOpenUrl(file.publicUrl),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NestColors.creamyWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NestColors.roseMist),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.insert_drive_file_outlined,
                    size: 20,
                    color: NestColors.clay,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${file.fileName} (${formatAttachmentSize(file.sizeBytes)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showImageDialog(BuildContext context, ChatAttachment img) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(img.publicUrl, fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedScheduleCard extends StatelessWidget {
  const _SharedScheduleCard({
    required this.schedule,
    this.onSaveToMyCalendar,
  });

  final SharedScheduleInfo schedule;
  final VoidCallback? onSaveToMyCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final whenParts = [
      if (schedule.date.isNotEmpty) schedule.date,
      if (schedule.dayLabel.isNotEmpty) schedule.dayLabel,
      if (schedule.timeRange.isNotEmpty) schedule.timeRange,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NestColors.dustyRose.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Nest3dIcon.calendar(size: 28),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: NestColors.roseMist,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  schedule.kindBadgeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NestColors.deepWood,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            schedule.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: NestColors.deepWood,
            ),
          ),
          if (whenParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time_outlined,
                  size: 14,
                  color: NestColors.clay,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    whenParts.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (schedule.className.isNotEmpty ||
              schedule.teacherName.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              [
                if (schedule.className.isNotEmpty) schedule.className,
                if (schedule.teacherName.isNotEmpty)
                  '${schedule.teacherName} 선생님',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.clay,
              ),
            ),
          ],
          if (schedule.location.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: NestColors.clay,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    schedule.location,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (schedule.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              schedule.note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.76),
              ),
            ),
          ],
          if (onSaveToMyCalendar != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSaveToMyCalendar,
                icon: const Icon(Icons.add_task_outlined, size: 16),
                label: const Text('내 일정에 담기'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SharedContactCard extends StatelessWidget {
  const _SharedContactCard({
    required this.contact,
    required this.onOpenUrl,
  });

  final SharedContactInfo contact;
  final Future<void> Function(String url) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NestColors.mutedSage.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EntityAvatar(label: contact.contactName, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.contactName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NestColors.deepWood,
                      ),
                    ),
                    if (contact.contactRole.isNotEmpty)
                      Text(
                        contact.contactRole,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: NestColors.clay,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (contact.phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: NestColors.clay),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    contact.phone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (contact.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: NestColors.clay),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    contact.email,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (contact.memo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              contact.memo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (contact.phone.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => onOpenUrl('tel:${contact.phone}'),
                  icon: const Icon(Icons.call_outlined, size: 15),
                  label: const Text('전화'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => onOpenUrl('sms:${contact.phone}'),
                  icon: const Icon(Icons.sms_outlined, size: 15),
                  label: const Text('문자'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  final copyTarget = contact.phone.isNotEmpty
                      ? contact.phone
                      : contact.email.isNotEmpty
                      ? contact.email
                      : contact.contactName;
                  Clipboard.setData(ClipboardData(text: copyTarget));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$copyTarget" 정보를 복사했습니다.')),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 15),
                label: const Text('복사'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 스케줄 공유 선택/입력 시트 ──

class _ShareScheduleSheet extends StatefulWidget {
  const _ShareScheduleSheet({required this.controller});

  final NestController controller;

  @override
  State<_ShareScheduleSheet> createState() => _ShareScheduleSheetState();
}

class _ShareScheduleSheetState extends State<_ShareScheduleSheet> {
  String _mode = 'TIMETABLE'; // 'TIMETABLE' | 'EVENTS' | 'CUSTOM'

  final _titleController = TextEditingController();
  final _timeRangeController = TextEditingController(text: '10:00 - 10:50');
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  static const _dayNames = ['일', '월', '화', '수', '목', '금', '토'];

  List<ClassSession> _availableSessions(NestController controller) {
    return controller.allTermSessions.isNotEmpty
        ? controller.allTermSessions
        : controller.sessions;
  }

  @override
  void initState() {
    super.initState();
    final sessions = _availableSessions(widget.controller);
    if (sessions.isEmpty && widget.controller.academicEvents.isNotEmpty) {
      _mode = 'EVENTS';
    } else if (sessions.isEmpty && widget.controller.academicEvents.isEmpty) {
      _mode = 'CUSTOM';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeRangeController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatClock(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final sessions = _availableSessions(controller);
    final events = controller.academicEvents;

    return NestSheet(
      title: '스케줄 공유하기',
      subtitle: '수업 시간표나 학사일정을 원클릭으로 채팅방에 공유하세요.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'TIMETABLE',
                icon: Icon(Icons.schedule_outlined, size: 16),
                label: Text('시간표 수업'),
              ),
              ButtonSegment(
                value: 'EVENTS',
                icon: Icon(Icons.event_note_outlined, size: 16),
                label: Text('학사일정'),
              ),
              ButtonSegment(
                value: 'CUSTOM',
                icon: Icon(Icons.edit_calendar_outlined, size: 16),
                label: Text('직접 입력'),
              ),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (next) => setState(() => _mode = next.first),
          ),
          const SizedBox(height: 12),
          if (_mode == 'TIMETABLE') ...[
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '현재 선택된 반에 등록된 수업 시간표가 없습니다. "직접 입력" 탭에서 일정을 바로 공유해 보세요.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final slot = controller.timeSlots
                        .where((s) => s.id == session.timeSlotId)
                        .firstOrNull;
                    final dayLabel = slot == null
                        ? ''
                        : '${_dayNames[slot.dayOfWeek % 7]}요일';
                    final timeRange = slot == null
                        ? ''
                        : '${_formatClock(slot.startTime)} - ${_formatClock(slot.endTime)}';
                    final courseName = controller.findCourseName(session.courseId);
                    final className = controller.findClassGroupName(
                      session.classGroupId,
                    );
                    final title = courseName != '-' ? courseName : session.title;

                    return Card(
                      child: ListTile(
                        leading: const Nest3dIcon.calendar(size: 32),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (className != '-') className,
                            if (dayLabel.isNotEmpty) dayLabel,
                            if (timeRange.isNotEmpty) timeRange,
                            if ((session.location ?? '').isNotEmpty)
                              session.location!,
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.send_rounded, size: 18),
                        onTap: () {
                          Navigator.of(context).pop(
                            SharedScheduleInfo(
                              scheduleKind: 'CLASS_SESSION',
                              title: title,
                              dayLabel: dayLabel,
                              timeRange: timeRange,
                              location: session.location ?? '',
                              className: className == '-' ? '' : className,
                              sourceId: session.id,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ] else if (_mode == 'EVENTS') ...[
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '등록된 학사일정이 없습니다. "직접 입력" 탭에서 일정을 바로 만들어 공유해 보세요.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final dateLabel = DateFormat(
                      'yyyy-MM-dd',
                    ).format(event.eventDate);
                    return Card(
                      child: ListTile(
                        leading: const Nest3dIcon.calendar(size: 32),
                        title: Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (dateLabel.isNotEmpty) dateLabel,
                            if (event.description.isNotEmpty) event.description,
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.send_rounded, size: 18),
                        onTap: () {
                          Navigator.of(context).pop(
                            SharedScheduleInfo(
                              scheduleKind: 'ACADEMIC_EVENT',
                              title: event.title,
                              date: dateLabel,
                              note: event.description,
                              sourceId: event.id,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ] else ...[
            TextField(
              key: const ValueKey('chat-custom-schedule-title'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '일정 제목',
                hintText: '예: 현장학습 모임 / 과학 실험 수업',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(_selectedDate),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _timeRangeController,
                    decoration: const InputDecoration(
                      labelText: '시간대',
                      hintText: '10:00 - 11:00',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '장소 (선택)',
                hintText: '예: 거실 배움터 / 어린이 과학관',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '메모 / 준비물 (선택)',
                hintText: '예: 개인 물통 지참',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('chat-custom-schedule-submit'),
              onPressed: () {
                final title = _titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.of(context).pop(
                  SharedScheduleInfo(
                    scheduleKind: 'CUSTOM_SCHEDULE',
                    title: title,
                    date: DateFormat('yyyy-MM-dd').format(_selectedDate),
                    dayLabel:
                        '${_dayNames[_selectedDate.weekday % 7]}요일',
                    timeRange: _timeRangeController.text.trim(),
                    location: _locationController.text.trim(),
                    note: _noteController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('이 스케줄 공유하기'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 연락처 공유 선택/입력 시트 ──

class _ShareContactSheet extends StatefulWidget {
  const _ShareContactSheet({required this.controller});

  final NestController controller;

  @override
  State<_ShareContactSheet> createState() => _ShareContactSheetState();
}

class _ShareContactSheetState extends State<_ShareContactSheet> {
  String _mode = 'DIRECTORY'; // 'DIRECTORY' | 'CUSTOM'

  final _nameController = TextEditingController();
  final _roleController = TextEditingController(text: '담당 선생님');
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_directoryContacts(widget.controller).isEmpty) {
      _mode = 'CUSTOM';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<SharedContactInfo> _directoryContacts(NestController controller) {
    final list = <SharedContactInfo>[];
    final seenNames = <String>{};

    for (final teacher in controller.teacherProfiles) {
      if (teacher.displayName.trim().isEmpty) continue;
      seenNames.add(teacher.displayName.trim());
      final memberEntry = (teacher.userId ?? '').isNotEmpty
          ? controller.findHomeschoolMemberByUserId(teacher.userId!)
          : null;
      list.add(
        SharedContactInfo(
          contactName: teacher.displayName.trim(),
          contactRole: '선생님',
          phone: teacher.phone,
          email: memberEntry?.email ?? '',
          userId: teacher.userId ?? '',
        ),
      );
    }

    for (final member in controller.homeschoolMemberDirectory) {
      final name = member.fullName.trim().isNotEmpty
          ? member.fullName.trim()
          : member.displayLabel.trim();
      if (name.isEmpty || seenNames.contains(name)) continue;
      seenNames.add(name);
      list.add(
        SharedContactInfo(
          contactName: name,
          contactRole: '홈스쿨 구성원',
          email: member.email,
          userId: member.userId,
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _directoryContacts(widget.controller);

    return NestSheet(
      title: '연락처 공유하기',
      subtitle: '선생님·보호자·외부 연락처를 원클릭으로 채팅방에 공유하세요.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'DIRECTORY',
                icon: Icon(Icons.people_outline, size: 16),
                label: Text('홈스쿨 구성원·교사'),
              ),
              ButtonSegment(
                value: 'CUSTOM',
                icon: Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: Text('직접 입력'),
              ),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (next) => setState(() => _mode = next.first),
          ),
          const SizedBox(height: 12),
          if (_mode == 'DIRECTORY') ...[
            if (contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '등록된 교사·구성원 연락처가 없습니다. "직접 입력" 탭에서 연락처를 바로 공유해 보세요.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final c = contacts[index];
                    return Card(
                      child: ListTile(
                        leading: EntityAvatar(label: c.contactName, size: 36),
                        title: Text(
                          c.contactName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (c.contactRole.isNotEmpty) c.contactRole,
                            if (c.phone.isNotEmpty) c.phone,
                            if (c.email.isNotEmpty) c.email,
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.send_rounded, size: 18),
                        onTap: () => Navigator.of(context).pop(c),
                      ),
                    );
                  },
                ),
              ),
          ] else ...[
            TextField(
              key: const ValueKey('chat-custom-contact-name'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '예: 김민지 선생님 / 과학관 안내데스크',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roleController,
                    decoration: const InputDecoration(
                      labelText: '역할 / 소속',
                      hintText: '예: 미술 전담 교사 / 엄마',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat-custom-contact-phone'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '전화번호',
                      hintText: '010-1234-5678',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일 (선택)',
                hintText: 'teacher@example.com',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '예: 수요일 오후 수업 문의 가능',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('chat-custom-contact-submit'),
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(context).pop(
                  SharedContactInfo(
                    contactName: name,
                    contactRole: _roleController.text.trim(),
                    phone: _phoneController.text.trim(),
                    email: _emailController.text.trim(),
                    memo: _memoController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('이 연락처 공유하기'),
            ),
          ],
        ],
      ),
    );
  }
}
