import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
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
    _syncComposerClassTarget(controller);
    _syncCommentControllers(controller.communityPosts);

    return ListView(
      children: [
        _buildComposerCard(controller),
        const SizedBox(height: 12),
        _buildFeedCard(controller),
      ],
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Community', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '부모/교사가 따뜻한 소식, 사진, 영상을 공유하는 공간입니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '새 글 작성',
                hintText: '오늘 아이들의 활동과 느낀 점을 공유해보세요.',
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
                      setState(() {
                        _targetClassGroupId = value == '__ALL__' ? null : value;
                      });
                    },
              decoration: const InputDecoration(labelText: '공개 범위'),
            ),
            const SizedBox(height: 10),
            _SelectedCommunityFileLabel(controller: controller),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy ? null : _pickMedia,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('사진/영상 첨부'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy ? null : _reloadFeed,
                  icon: const Icon(Icons.refresh),
                  label: const Text('피드 새로고침'),
                ),
                FilledButton.icon(
                  onPressed: controller.isBusy || !controller.canWriteCommunity
                      ? null
                      : _publishPost,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('게시'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (controller.communityPosts.isEmpty)
              const Text('아직 공유된 글이 없습니다. 첫 글을 남겨보세요.')
            else
              ...controller.communityPosts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CommunityPostCard(
                    post: post,
                    media: controller.mediaForCommunityPost(post.id),
                    comments: controller.commentsForCommunityPost(post.id),
                    liked: controller.isCommunityPostLiked(post.id),
                    likeCount: controller.likesForCommunityPost(post.id),
                    classGroupName: controller.findClassGroupName(
                      post.classGroupId,
                    ),
                    commentController: _commentControllers[post.id]!,
                    isBusy: controller.isBusy,
                    onLike: () => _toggleLike(post.id),
                    onComment: () => _submitComment(post.id),
                    onOpenMediaLink: _openLink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

    final text = commentController.text;
    try {
      await widget.controller.addCommunityComment(
        postId: postId,
        content: text,
      );
      commentController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
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

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
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

  @override
  Widget build(BuildContext context) {
    final createdLabel = post.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(post.createdAt!.toLocal());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NestColors.roseMist),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: NestColors.roseMist,
                child: Text(
                  post.authorDisplayName.isEmpty
                      ? '?'
                      : post.authorDisplayName.substring(0, 1),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
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
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(post.content),
          ],
          if (media.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...media.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NestColors.roseMist),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.isVideo
                            ? Icons.videocam_rounded
                            : Icons.photo_camera_back_rounded,
                        color: NestColors.deepWood,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title.isEmpty ? '첨부 파일' : item.title,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (item.driveWebViewLink != null &&
                          item.driveWebViewLink!.isNotEmpty)
                        FilledButton.tonal(
                          onPressed: () =>
                              onOpenMediaLink(item.driveWebViewLink!),
                          child: const Text('열기'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: isBusy ? null : onLike,
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.redAccent : null,
                ),
                label: Text('좋아요 $likeCount'),
              ),
              const SizedBox(width: 10),
              Text('댓글 ${comments.length}'),
            ],
          ),
          const SizedBox(height: 4),
          if (comments.isNotEmpty)
            ...comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall,
                    children: [
                      TextSpan(
                        text: '${comment.authorDisplayName}: ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: comment.content),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: '댓글을 입력하세요',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isBusy ? null : onComment,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
