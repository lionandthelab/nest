import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/entity_visuals.dart';
import '../widgets/nest_empty_state.dart';
import 'gallery_tab.dart';

class CommunityFeedTab extends StatefulWidget {
  const CommunityFeedTab({
    super.key,
    required this.controller,
    this.showGalleryLauncher = false,
    this.showHeroHeader = true,
    this.title = '커뮤니티',
    this.subtitle = '반별 활동, 사진, 짧은 메모를 실제 피드처럼 빠르게 확인하고 반응합니다.',
  });

  final NestController controller;
  final bool showGalleryLauncher;
  final bool showHeroHeader;
  final String title;
  final String subtitle;

  @override
  State<CommunityFeedTab> createState() => _CommunityFeedTabState();
}

class _CommunityFeedTabState extends State<CommunityFeedTab> {
  final _postController = TextEditingController();
  final Map<String, TextEditingController> _commentControllers = {};

  String? _targetClassGroupId;
  bool _composerClassInitialized = false;

  @override
  void dispose() {
    _postController.dispose();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final posts = controller.communityPosts.toList(growable: false)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    _syncComposerClassTarget(controller);
    _syncCommentControllers(posts);

    // Build the fixed header items list for index offset calculation.
    // Layout: [heroCard, heroSpacer?], composerCard, composerSpacer,
    //         [emptyState | post0, post1, ...]
    final headerCount = widget.showHeroHeader ? 2 : 0; // hero + spacer
    // composer + spacer = 2 fixed items after header
    const composerCount = 2;
    final fixedCount = headerCount + composerCount;

    return RefreshIndicator(
      onRefresh: _reloadFeed,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: fixedCount + (posts.isEmpty ? 1 : posts.length),
        itemBuilder: (context, index) {
          if (widget.showHeroHeader) {
            if (index == 0) return _buildHeroCard(controller, posts);
            if (index == 1) return const SizedBox(height: 12);
          }
          final afterHeader = index - headerCount;
          if (afterHeader == 0) return _buildComposerCard(controller);
          if (afterHeader == 1) return const SizedBox(height: 12);

          final postIndex = afterHeader - composerCount;
          if (posts.isEmpty) {
            return const NestEmptyState(
              icon: Icons.forum_outlined,
              title: '아직 공유된 글이 없습니다',
              subtitle: '첫 게시글을 올리면 이 화면이 실제 SNS 피드처럼 쌓입니다.',
            );
          }
          final post = posts[postIndex];
          final reportCount = controller.openReportsForCommunityPost(post.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CommunityPostCard(
              post: post,
              media: controller.mediaForCommunityPost(post.id),
              comments: controller.commentsForCommunityPost(post.id),
              liked: controller.isCommunityPostLiked(post.id),
              likeCount: controller.likesForCommunityPost(post.id),
              classGroupName: controller.findClassGroupName(post.classGroupId),
              reportCount: reportCount,
              commentController: _commentControllers[post.id]!,
              isBusy: controller.isBusy,
              onLike: () => _toggleLike(post.id),
              onComment: () => _submitComment(post.id),
              onOpenMediaLink: _openLink,
              onReport: () => _showReportDialog(post.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(NestController controller, List<CommunityPost> posts) {
    final mediaCount = posts.fold<int>(
      0,
      (count, post) => count + controller.mediaForCommunityPost(post.id).length,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NestColors.dustyRose.withValues(alpha: 0.22),
                NestColors.creamyWhite,
                NestColors.mutedSage.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(color: NestColors.roseMist),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EntityAvatar(
                    label: widget.title,
                    icon: Icons.forum_outlined,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: NestColors.deepWood.withValues(
                                  alpha: 0.74,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FeedStatPill(
                    icon: Icons.dynamic_feed_outlined,
                    label: '게시글 ${posts.length}',
                  ),
                  _FeedStatPill(
                    icon: Icons.photo_library_outlined,
                    label: '첨부 $mediaCount',
                  ),
                  _FeedStatPill(
                    icon: Icons.people_alt_outlined,
                    label: '반 ${widget.controller.classGroups.length}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy ? null : _reloadFeed,
                    icon: const Icon(Icons.refresh),
                    label: const Text('피드 새로고침'),
                  ),
                  if (widget.showGalleryLauncher)
                    ElevatedButton.icon(
                      onPressed: _openGalleryPage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('갤러리 열기'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposerCard(NestController controller) {
    final classGroupOptions = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '__ALL__', child: Text('전체 공개')),
      ...controller.classGroups.map(
        (group) => DropdownMenuItem(value: group.id, child: Text(group.name)),
      ),
    ];
    final dropdownValue = _targetClassGroupId ?? '__ALL__';
    final canWrite = controller.canWriteCommunity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntityAvatar(
                  label: _composerName(controller),
                  icon: Icons.person_outline,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘 소식을 올려보세요',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '짧은 문장, 사진, 영상 위주로 올리면 모바일에서 훨씬 읽기 좋습니다.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postController,
              enabled: canWrite,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '오늘 아이들의 활동, 사진 설명, 간단한 공지를 남겨보세요.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(dropdownValue),
              initialValue: dropdownValue,
              items: classGroupOptions,
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _targetClassGroupId = value == '__ALL__' ? null : value;
                      });
                    },
              decoration: const InputDecoration(
                labelText: '공개 범위',
                prefixIcon: Icon(Icons.public),
              ),
            ),
            const SizedBox(height: 10),
            _SelectedCommunityFileLabel(controller: controller),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy || !canWrite ? null : _pickMedia,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('사진/영상'),
                ),
                if (widget.showGalleryLauncher && !widget.showHeroHeader)
                  FilledButton.tonalIcon(
                    onPressed: _openGalleryPage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('갤러리'),
                  ),
                FilledButton.icon(
                  onPressed: controller.isBusy || !canWrite
                      ? null
                      : _publishPost,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('게시'),
                ),
              ],
            ),
            if (!canWrite) ...[
              const SizedBox(height: 10),
              Text(
                '현재 역할에서는 글 작성이 제한되어 있습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.68),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _composerName(NestController controller) {
    final displayName = controller.findMemberDisplayName(controller.user?.id);
    if (displayName != '-' && displayName.trim().isNotEmpty) {
      return displayName;
    }
    final email = controller.user?.email ?? '';
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return 'Me';
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

  void _syncCommentControllers(List<CommunityPost> posts) {
    final activePostIds = posts.map((post) => post.id).toSet();

    final removed = _commentControllers.keys
        .where((postId) => !activePostIds.contains(postId))
        .toList(growable: false);
    for (final postId in removed) {
      _commentControllers.remove(postId)?.dispose();
    }

    for (final post in posts) {
      _commentControllers.putIfAbsent(post.id, () => TextEditingController());
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

  Future<void> _reloadFeed() async {
    try {
      await widget.controller.loadCommunityFeed();
      _showMessage('커뮤니티 피드를 새로고침했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      await widget.controller.toggleCommunityLike(postId);
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _submitComment(String postId) async {
    final commentController = _commentControllers[postId];
    if (commentController == null) {
      return;
    }

    try {
      await widget.controller.addCommunityComment(
        postId: postId,
        content: commentController.text,
      );
      commentController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _showReportDialog(String postId) async {
    String reasonCategory = 'OTHER';
    final detailController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('게시글 신고'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: reasonCategory,
                    decoration: const InputDecoration(labelText: '사유'),
                    items: const [
                      DropdownMenuItem(value: 'SPAM', child: Text('스팸')),
                      DropdownMenuItem(value: 'ABUSE', child: Text('비방/욕설')),
                      DropdownMenuItem(value: 'SAFETY', child: Text('안전 문제')),
                      DropdownMenuItem(
                        value: 'INAPPROPRIATE',
                        child: Text('부적절한 내용'),
                      ),
                      DropdownMenuItem(value: 'OTHER', child: Text('기타')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setLocalState(() {
                        reasonCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '상세 내용'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('신고 제출'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) {
      detailController.dispose();
      return;
    }

    try {
      await widget.controller.reportCommunityPost(
        postId: postId,
        reasonCategory: reasonCategory,
        reasonDetail: detailController.text.trim(),
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    } finally {
      detailController.dispose();
    }
  }

  Future<void> _openLink(String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );

    if (!launched) {
      _showMessage('링크를 열지 못했습니다.');
    }
  }

  Future<void> _openGalleryPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GalleryPage(controller: widget.controller),
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _FeedStatPill extends StatelessWidget {
  const _FeedStatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: NestColors.deepWood),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(14),
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
                  : controller.clearPendingCommunityFile,
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.media,
    required this.comments,
    required this.liked,
    required this.likeCount,
    required this.classGroupName,
    required this.reportCount,
    required this.commentController,
    required this.isBusy,
    required this.onLike,
    required this.onComment,
    required this.onOpenMediaLink,
    required this.onReport,
  });

  final CommunityPost post;
  final List<CommunityPostMedia> media;
  final List<CommunityComment> comments;
  final bool liked;
  final int likeCount;
  final String classGroupName;
  final int reportCount;
  final TextEditingController commentController;
  final bool isBusy;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final Future<void> Function(String url) onOpenMediaLink;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final createdLabel = post.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(post.createdAt!.toLocal());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NestColors.roseMist),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: NestColors.deepWood.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityAvatar(
                label: post.authorDisplayName,
                icon: Icons.person_outline,
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          post.authorDisplayName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (post.isPinned)
                          _PostBadge(
                            icon: Icons.push_pin_outlined,
                            label: '고정',
                          ),
                        if (reportCount > 0)
                          _PostBadge(
                            icon: Icons.report_gmailerrorred,
                            label: '신고 $reportCount',
                            accent: NestColors.clay,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$createdLabel · $classGroupName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.content.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.content.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          if (media.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...media.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CommunityMediaCard(
                  item: item,
                  onOpenMediaLink: onOpenMediaLink,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: isBusy ? null : onLike,
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.redAccent : null,
                ),
                label: Text('좋아요 $likeCount'),
              ),
              FilledButton.tonalIcon(
                onPressed: isBusy ? null : onReport,
                icon: const Icon(Icons.flag_outlined),
                label: Text('신고 ${reportCount > 0 ? reportCount : ''}'.trim()),
              ),
              _PostCounter(
                icon: Icons.chat_bubble_outline,
                label: '댓글 ${comments.length}',
              ),
            ],
          ),
          if (comments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: NestColors.creamyWhite,
                    border: Border.all(color: NestColors.roseMist),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: '${comment.authorDisplayName}  ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: comment.content),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: NestColors.creamyWhite,
              border: Border.all(color: NestColors.roseMist),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '댓글을 입력하세요',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isBusy ? null : onComment,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityMediaCard extends StatelessWidget {
  const _CommunityMediaCard({
    required this.item,
    required this.onOpenMediaLink,
  });

  final CommunityPostMedia item;
  final Future<void> Function(String url) onOpenMediaLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.isVideo
              ? [NestColors.mutedSage.withValues(alpha: 0.22), Colors.white]
              : [NestColors.roseMist.withValues(alpha: 0.36), Colors.white],
        ),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.92),
            ),
            child: Icon(
              item.isVideo
                  ? Icons.videocam_rounded
                  : Icons.photo_camera_back_rounded,
              color: NestColors.deepWood,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.isEmpty ? '첨부 파일' : item.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  item.isVideo ? '동영상 첨부' : '사진 첨부',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
          if (item.driveWebViewLink != null &&
              item.driveWebViewLink!.isNotEmpty)
            FilledButton.tonal(
              onPressed: () => onOpenMediaLink(item.driveWebViewLink!),
              child: const Text('열기'),
            ),
        ],
      ),
    );
  }
}

class _PostBadge extends StatelessWidget {
  const _PostBadge({
    required this.icon,
    required this.label,
    this.accent = NestColors.dustyRose,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: 0.14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: NestColors.deepWood),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PostCounter extends StatelessWidget {
  const _PostCounter({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: NestColors.deepWood),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
