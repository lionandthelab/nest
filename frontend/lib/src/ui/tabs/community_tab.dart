import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';

enum _PostFilter { all, reported, hidden, pinned }

class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  final _postController = TextEditingController();

  String? _targetClassGroupId;
  bool _composerClassInitialized = false;
  _PostFilter _postFilter = _PostFilter.all;

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncComposerClassTarget(controller);

    if (!controller.canModerateCommunity) {
      return _buildPermissionFallback(controller);
    }

    final filteredPosts = _filteredPosts(controller);
    final openReports = controller.communityReports
        .where((report) => report.isOpen)
        .toList();

    return ListView(
      children: [
        _buildSummaryCard(controller, filteredPosts.length, openReports.length),
        const SizedBox(height: 12),
        _buildReportQueueCard(controller, openReports),
        const SizedBox(height: 12),
        _buildPostManagerSection(controller, filteredPosts),
      ],
    );
  }

  Widget _buildPermissionFallback(NestController controller) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '커뮤니티 관리',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text('이 탭은 관리자/스태프 전용 관리 화면입니다.'),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy ? null : _reloadFeed,
                  icon: const Icon(Icons.refresh),
                  label: const Text('피드 새로고침'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    NestController controller,
    int filteredPostCount,
    int openReportCount,
  ) {
    final hiddenCount = controller.communityPosts
        .where((post) => post.isHidden)
        .length;
    final pinnedCount = controller.communityPosts
        .where((post) => post.isPinned)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SNS 관리',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '게시글 관리, 신고 접수 처리, 숨김/고정 상태를 한 화면에서 운영합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: '전체 게시글',
                  value: '${controller.communityPosts.length}',
                ),
                _MetricChip(label: '필터 결과', value: '$filteredPostCount'),
                _MetricChip(label: '미처리 신고', value: '$openReportCount'),
                _MetricChip(label: '숨김 게시글', value: '$hiddenCount'),
                _MetricChip(label: '고정 게시글', value: '$pinnedCount'),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: controller.isBusy ? null : _reloadFeed,
              icon: const Icon(Icons.refresh),
              label: const Text('관리 데이터 새로고침'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportQueueCard(
    NestController controller,
    List<CommunityReport> openReports,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('신고 큐', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (openReports.isEmpty)
              const NestEmptyState(
                icon: Icons.flag_outlined,
                title: '미처리 신고가 없습니다.',
              )
            else
              ...openReports.take(40).map((report) {
                final post = controller.communityPosts
                    .where((row) => row.id == report.postId)
                    .firstOrNull;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Chip(label: Text('카테고리: ${report.reasonCategory}')),
                            Chip(
                              label: Text('신고자: ${report.reporterDisplayName}'),
                            ),
                            Chip(
                              avatar: const Icon(Icons.schedule, size: 16),
                              label: Text(_formatDate(report.createdAt)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          report.reasonDetail.isEmpty
                              ? '상세 사유 없음'
                              : report.reasonDetail,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post == null
                              ? '원본 게시글을 찾을 수 없습니다.'
                              : '원글: ${post.content.isEmpty ? '(내용 없음)' : post.content}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: controller.isBusy
                                  ? null
                                  : () => _resolveReport(report.id),
                              icon: const Icon(Icons.check),
                              label: const Text('해결 처리'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: controller.isBusy
                                  ? null
                                  : () => _dismissReport(report.id),
                              icon: const Icon(Icons.remove_done),
                              label: const Text('기각'),
                            ),
                            if (post != null)
                              FilledButton.tonalIcon(
                                onPressed: controller.isBusy || post.isHidden
                                    ? null
                                    : () => _hidePost(post.id),
                                icon: const Icon(Icons.visibility_off),
                                label: const Text('게시글 숨김'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _openComposerModal(NestController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _CommunityComposerModal(
          controller: controller,
          postController: _postController,
          targetClassGroupId: _targetClassGroupId,
          onTargetChanged: (value) {
            setState(() {
              _targetClassGroupId = value;
            });
          },
          onPickMedia: _pickMedia,
          onPublish: () async {
            final navigator = Navigator.of(ctx);
            await _publishPost();
            if (mounted) navigator.pop();
          },
        );
      },
    );
  }

  Widget _buildPostManagerSection(
    NestController controller,
    List<CommunityPost> posts,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '게시글 관리',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () => _openComposerModal(controller),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('게시글 작성'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFilterBar(controller),
          const SizedBox(height: 10),
          if (posts.isEmpty)
            const NestEmptyState(
              icon: Icons.article_outlined,
              title: '선택된 조건의 게시글이 없습니다.',
            )
          else
            ...posts.map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PostModerationCard(
                  post: post,
                  classGroupName: controller.findClassGroupName(
                    post.classGroupId,
                  ),
                  likeCount: controller.likesForCommunityPost(post.id),
                  commentCount: controller
                      .commentsForCommunityPost(post.id)
                      .length,
                  mediaCount: controller
                      .mediaForCommunityPost(post.id)
                      .length,
                  openReportCount: controller.openReportsForCommunityPost(
                    post.id,
                  ),
                  canAct: !controller.isBusy,
                  onTogglePinned: () => _togglePinned(post),
                  onToggleHidden: () => _toggleHidden(post),
                  onDelete: () => _deletePost(post.id),
                  onOpenFirstMedia: () =>
                      _openFirstMedia(controller, post.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(NestController controller) {
    final reportedCount = controller.communityPosts
        .where((post) => controller.openReportsForCommunityPost(post.id) > 0)
        .length;
    final hiddenCount = controller.communityPosts
        .where((post) => post.isHidden)
        .length;
    final pinnedCount = controller.communityPosts
        .where((post) => post.isPinned)
        .length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          selected: _postFilter == _PostFilter.all,
          onSelected: (_) => setState(() => _postFilter = _PostFilter.all),
          label: Text('전체 (${controller.communityPosts.length})'),
        ),
        ChoiceChip(
          selected: _postFilter == _PostFilter.reported,
          onSelected: (_) => setState(() => _postFilter = _PostFilter.reported),
          label: Text('신고 ($reportedCount)'),
        ),
        ChoiceChip(
          selected: _postFilter == _PostFilter.hidden,
          onSelected: (_) => setState(() => _postFilter = _PostFilter.hidden),
          label: Text('숨김 ($hiddenCount)'),
        ),
        ChoiceChip(
          selected: _postFilter == _PostFilter.pinned,
          onSelected: (_) => setState(() => _postFilter = _PostFilter.pinned),
          label: Text('고정 ($pinnedCount)'),
        ),
      ],
    );
  }

  List<CommunityPost> _filteredPosts(NestController controller) {
    final rows = controller.communityPosts;

    return switch (_postFilter) {
      _PostFilter.all => rows,
      _PostFilter.reported =>
        rows
            .where(
              (post) => controller.openReportsForCommunityPost(post.id) > 0,
            )
            .toList(),
      _PostFilter.hidden =>
        rows.where((post) => post.isHidden).toList(),
      _PostFilter.pinned =>
        rows.where((post) => post.isPinned).toList(),
    };
  }

  void _syncComposerClassTarget(NestController controller) {
    final validIds = controller.classGroups.map((group) => group.id).toSet();
    if (!_composerClassInitialized) {
      _targetClassGroupId = controller.selectedClassGroupId;
      _composerClassInitialized = true;
      return;
    }

    if (_targetClassGroupId != null &&
        !validIds.contains(_targetClassGroupId)) {
      _targetClassGroupId = controller.selectedClassGroupId;
    }
  }

  Future<void> _reloadFeed() async {
    try {
      await widget.controller.loadCommunityFeed();
      _showMessage('관리 데이터를 새로고침했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _pickMedia() async {
    try {
      await widget.controller.pickCommunityMediaFile();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _publishPost() async {
    try {
      await widget.controller.publishCommunityPost(
        content: _postController.text,
        classGroupId: _targetClassGroupId,
      );
      _postController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _resolveReport(String reportId) async {
    try {
      await widget.controller.setCommunityReportStatus(
        reportId: reportId,
        status: 'RESOLVED',
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      await widget.controller.setCommunityReportStatus(
        reportId: reportId,
        status: 'DISMISSED',
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _hidePost(String postId) async {
    try {
      await widget.controller.setCommunityPostHidden(
        postId: postId,
        hidden: true,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _togglePinned(CommunityPost post) async {
    try {
      await widget.controller.setCommunityPostPinned(
        postId: post.id,
        pinned: !post.isPinned,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _toggleHidden(CommunityPost post) async {
    try {
      await widget.controller.setCommunityPostHidden(
        postId: post.id,
        hidden: !post.isHidden,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await widget.controller.deleteCommunityPost(postId);
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _openFirstMedia(NestController controller, String postId) async {
    final mediaRows = controller.mediaForCommunityPost(postId);
    final firstLink = mediaRows
        .map((row) => row.driveWebViewLink)
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .firstOrNull;

    if (firstLink == null) {
      _showMessage('열 수 있는 미디어 링크가 없습니다.');
      return;
    }

    final launched = await launchUrl(
      Uri.parse(firstLink),
      mode: LaunchMode.platformDefault,
    );

    if (!launched) {
      _showMessage('링크를 열지 못했습니다.');
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.analytics_outlined, size: 16),
      label: Text('$label: $value'),
    );
  }
}

class _SelectedCommunityFileLabel extends StatelessWidget {
  const _SelectedCommunityFileLabel({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final file = controller.pendingCommunityMediaFile;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
        color: file == null
            ? Colors.white
            : NestColors.mutedSage.withValues(alpha: 0.14),
      ),
      child: Row(
        children: [
          Icon(
            file == null ? Icons.file_present_outlined : Icons.task_alt,
            color: NestColors.deepWood,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file == null
                  ? '첨부된 파일 없음'
                  : '${file.name} (${file.sizeBytes} bytes)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (file != null)
            IconButton(
              onPressed: controller.isBusy
                  ? null
                  : () {
                      controller.clearPendingCommunityFile();
                    },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }
}

class _PostModerationCard extends StatelessWidget {
  const _PostModerationCard({
    required this.post,
    required this.classGroupName,
    required this.likeCount,
    required this.commentCount,
    required this.mediaCount,
    required this.openReportCount,
    required this.canAct,
    required this.onTogglePinned,
    required this.onToggleHidden,
    required this.onDelete,
    required this.onOpenFirstMedia,
  });

  final CommunityPost post;
  final String classGroupName;
  final int likeCount;
  final int commentCount;
  final int mediaCount;
  final int openReportCount;
  final bool canAct;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleHidden;
  final VoidCallback onDelete;
  final VoidCallback onOpenFirstMedia;

  @override
  Widget build(BuildContext context) {
    final createdLabel = post.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(post.createdAt!.toLocal());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorDisplayName),
                    Text(
                      '$createdLabel · $classGroupName',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (post.isPinned)
                const Chip(
                  avatar: Icon(Icons.push_pin, size: 16),
                  label: Text('고정'),
                ),
              if (post.isHidden)
                const Chip(
                  avatar: Icon(Icons.visibility_off, size: 16),
                  label: Text('숨김'),
                ),
              if (openReportCount > 0)
                Chip(
                  avatar: const Icon(Icons.report_gmailerrorred, size: 16),
                  label: Text('신고 $openReportCount'),
                ),
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Text(
            '좋아요 $likeCount · 댓글 $commentCount · 첨부 $mediaCount',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: canAct ? onTogglePinned : null,
                icon: Icon(
                  post.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                label: Text(post.isPinned ? '고정 해제' : '상단 고정'),
              ),
              FilledButton.tonalIcon(
                onPressed: canAct ? onToggleHidden : null,
                icon: Icon(
                  post.isHidden ? Icons.visibility : Icons.visibility_off,
                ),
                label: Text(post.isHidden ? '숨김 해제' : '숨김'),
              ),
              FilledButton.tonalIcon(
                onPressed: mediaCount > 0 ? onOpenFirstMedia : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('첨부 열기'),
              ),
              FilledButton.tonalIcon(
                onPressed: canAct ? onDelete : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC25A4A),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityComposerModal extends StatelessWidget {
  const _CommunityComposerModal({
    required this.controller,
    required this.postController,
    required this.targetClassGroupId,
    required this.onTargetChanged,
    required this.onPickMedia,
    required this.onPublish,
  });

  final NestController controller;
  final TextEditingController postController;
  final String? targetClassGroupId;
  final ValueChanged<String?> onTargetChanged;
  final VoidCallback onPickMedia;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final classGroupOptions = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '__ALL__', child: Text('전체 공개')),
      ...controller.classGroups.map(
        (group) => DropdownMenuItem(value: group.id, child: Text(group.name)),
      ),
    ];
    final dropdownValue = targetClassGroupId ?? '__ALL__';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('게시글 작성', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: postController,
            minLines: 2,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '게시 내용',
              hintText: '운영 공지 또는 공용 소식을 등록하세요.',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(dropdownValue),
            initialValue: dropdownValue,
            items: classGroupOptions,
            onChanged: controller.isBusy
                ? null
                : (value) {
                    onTargetChanged(value == '__ALL__' ? null : value);
                  },
            decoration: const InputDecoration(labelText: '공개 범위'),
          ),
          const SizedBox(height: 8),
          _SelectedCommunityFileLabel(controller: controller),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: controller.isBusy ? null : onPickMedia,
                icon: const Icon(Icons.attach_file),
                label: const Text('첨부'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed:
                    controller.isBusy || !controller.canWriteCommunity
                        ? null
                        : onPublish,
                icon: const Icon(Icons.send_rounded),
                label: const Text('게시'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
