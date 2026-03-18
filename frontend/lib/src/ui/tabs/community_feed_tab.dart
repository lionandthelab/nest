import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/entity_visuals.dart';
import '../widgets/nest_empty_state.dart';

class CommunityFeedTab extends StatefulWidget {
  const CommunityFeedTab({
    super.key,
    required this.controller,
    this.showGalleryLauncher = false,
    this.showHeroHeader = false,
    this.title = '커뮤니티',
    this.subtitle = '',
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
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    _syncComposerClassTarget(controller);
    _syncCommentControllers(posts);

    return Scaffold(
      backgroundColor: NestColors.creamyWhite,
      floatingActionButton: controller.canWriteCommunity
          ? FloatingActionButton(
              onPressed: () => _openComposeModal(controller),
              backgroundColor: NestColors.dustyRose,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _reloadFeed,
        child: posts.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  NestEmptyState(
                    icon: Icons.camera_alt_outlined,
                    title: '아직 게시글이 없습니다',
                    subtitle: '오른쪽 아래 + 버튼으로 첫 게시글을 올려보세요.',
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: posts.length,
                separatorBuilder: (context, i) =>
                    Divider(height: 1, color: NestColors.roseMist.withValues(alpha: 0.5)),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _InstagramPostCard(
                    post: post,
                    media: controller.mediaForCommunityPost(post.id),
                    comments: controller.commentsForCommunityPost(post.id),
                    liked: controller.isCommunityPostLiked(post.id),
                    likeCount: controller.likesForCommunityPost(post.id),
                    classGroupName:
                        controller.findClassGroupName(post.classGroupId),
                    commentController: _commentControllers[post.id]!,
                    isBusy: controller.isBusy,
                    onLike: () => _toggleLike(post.id),
                    onComment: () => _submitComment(post.id),
                    onOpenMediaLink: _openLink,
                    onReport: () => _showReportDialog(post.id),
                  );
                },
              ),
      ),
    );
  }

  // ── Compose Modal (Instagram-style) ──

  void _openComposeModal(NestController controller) {
    final classGroupOptions = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '__ALL__', child: Text('전체 공개')),
      ...controller.classGroups.map(
        (group) => DropdownMenuItem(value: group.id, child: Text(group.name)),
      ),
    ];
    final dropdownValue = _targetClassGroupId ?? '__ALL__';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: NestColors.deepWood.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '새 게시글',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _postController,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '무슨 이야기를 나눌까요?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(dropdownValue),
                    initialValue: dropdownValue,
                    items: classGroupOptions,
                    onChanged: controller.isBusy
                        ? null
                        : (value) {
                            setState(() {
                              _targetClassGroupId =
                                  value == '__ALL__' ? null : value;
                            });
                            setModalState(() {});
                          },
                    decoration: const InputDecoration(
                      labelText: '공개 범위',
                      prefixIcon: Icon(Icons.public),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelectedCommunityFileLabel(controller: controller),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton.filled(
                        onPressed:
                            controller.isBusy ? null : _pickMedia,
                        icon: const Icon(Icons.photo_library_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              NestColors.roseMist.withValues(alpha: 0.5),
                          foregroundColor: NestColors.deepWood,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: controller.isBusy
                            ? null
                            : () async {
                                final navigator = Navigator.of(ctx);
                                await _publishPost();
                                if (mounted) navigator.pop();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: NestColors.dustyRose,
                        ),
                        child: const Text('게시하기'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Business Logic ──

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
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      await widget.controller.toggleCommunityLike(postId);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _submitComment(String postId) async {
    final commentController = _commentControllers[postId];
    if (commentController == null) return;
    try {
      await widget.controller.addCommunityComment(
        postId: postId,
        content: commentController.text,
      );
      commentController.clear();
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
                      DropdownMenuItem(
                          value: 'SAFETY', child: Text('안전 문제')),
                      DropdownMenuItem(
                          value: 'INAPPROPRIATE', child: Text('부적절한 내용')),
                      DropdownMenuItem(value: 'OTHER', child: Text('기타')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => reasonCategory = value);
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
    if (!launched) _showMessage('링크를 열지 못했습니다.');
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

// ── Instagram-style Post Card ──

class _InstagramPostCard extends StatelessWidget {
  const _InstagramPostCard({
    required this.post,
    required this.media,
    required this.comments,
    required this.liked,
    required this.likeCount,
    required this.classGroupName,
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
  final TextEditingController commentController;
  final bool isBusy;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final Future<void> Function(String url) onOpenMediaLink;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdLabel = post.createdAt == null
        ? ''
        : _timeAgo(post.createdAt!);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar + name + time ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                EntityAvatar(
                  label: post.authorDisplayName,
                  icon: Icons.person_outline,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorDisplayName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$classGroupName · $createdLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin, size: 16, color: NestColors.dustyRose),
                  ),
                IconButton(
                  onPressed: onReport,
                  icon: Icon(
                    Icons.more_horiz,
                    color: NestColors.deepWood.withValues(alpha: 0.5),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // ── Media area ──
          if (media.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...media.map((item) => _InstagramMediaTile(
                  item: item,
                  onOpenMediaLink: onOpenMediaLink,
                )),
          ],

          // ── Content text ──
          if (post.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                post.content.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),

          // ── Action bar: like, comment, report ──
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: isBusy ? null : onLike,
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.redAccent : NestColors.deepWood,
                  ),
                ),
                IconButton(
                  onPressed: null,
                  icon: Icon(Icons.chat_bubble_outline, color: NestColors.deepWood),
                ),
                IconButton(
                  onPressed: isBusy ? null : onReport,
                  icon: Icon(Icons.flag_outlined, color: NestColors.deepWood),
                ),
              ],
            ),
          ),

          // ── Like count ──
          if (likeCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Text(
                '좋아요 $likeCount개',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),

          // ── Comments ──
          if (comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comments.take(3).map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall,
                        children: [
                          TextSpan(
                            text: '${c.authorDisplayName}  ',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: c.content),
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),

          if (comments.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
              child: Text(
                '댓글 ${comments.length}개 모두 보기',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.5),
                ),
              ),
            ),

          // ── Comment input ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    style: theme.textTheme.bodySmall,
                    decoration: InputDecoration(
                      hintText: '댓글 달기...',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: isBusy ? null : onComment,
                  child: Text(
                    '게시',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.dustyRose,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일').format(dt);
  }
}

// ── Instagram-style media tile ──

class _InstagramMediaTile extends StatelessWidget {
  const _InstagramMediaTile({
    required this.item,
    required this.onOpenMediaLink,
  });

  final CommunityPostMedia item;
  final Future<void> Function(String url) onOpenMediaLink;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.driveWebViewLink != null && item.driveWebViewLink!.isNotEmpty
          ? () => onOpenMediaLink(item.driveWebViewLink!)
          : null,
      child: Container(
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: item.isVideo
                ? [
                    NestColors.mutedSage.withValues(alpha: 0.22),
                    NestColors.mutedSage.withValues(alpha: 0.08),
                  ]
                : [
                    NestColors.roseMist.withValues(alpha: 0.32),
                    NestColors.roseMist.withValues(alpha: 0.10),
                  ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.isVideo ? Icons.play_circle_outline : Icons.photo_outlined,
              size: 48,
              color: NestColors.deepWood.withValues(alpha: 0.4),
            ),
            if (item.title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (item.driveWebViewLink != null &&
                item.driveWebViewLink!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '탭하여 열기',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: NestColors.dustyRose,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Composer file label ──

class _SelectedCommunityFileLabel extends StatelessWidget {
  const _SelectedCommunityFileLabel({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final file = controller.pendingCommunityMediaFile;
    if (file == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
        color: NestColors.mutedSage.withValues(alpha: 0.14),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt, size: 18, color: NestColors.deepWood),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${file.name} (${file.sizeBytes} bytes)',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed:
                controller.isBusy ? null : controller.clearPendingCommunityFile,
            icon: const Icon(Icons.clear, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
