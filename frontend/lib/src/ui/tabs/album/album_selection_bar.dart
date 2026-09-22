import 'package:flutter/material.dart';

import '../../nest_theme.dart';
import '../../widgets/nest_motion.dart';

/// 선택 모드의 하단 액션 바.
///
/// 앱에 선택 모드가 있는 화면은 여기가 처음이라, 하단 도크(NestDockBar)와 같은
/// 표면·테두리를 써서 새로 붙인 물건처럼 보이지 않게 한다.
class AlbumSelectionBar extends StatelessWidget {
  const AlbumSelectionBar({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onClear,
    required this.onDownload,
    this.onDelete,
    this.busy = false,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = selectedCount > 0;
    // '전체 선택'은 좁은 화면에서 가장 먼저 자리를 내준다. 같은 일을 타일
    // 길게 누르기로도 할 수 있고, 다운로드·삭제·취소는 대체 경로가 없다.
    final compact = MediaQuery.sizeOf(context).width < 600;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: nestReduceMotion(context)
            ? Duration.zero
            : NestMotion.pressOut,
        curve: NestMotion.pressCurve,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: NestColors.roseMist.withValues(alpha: 0.9),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '$selectedCount개 선택',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: busy
                          ? null
                          : (allSelected ? onClear : onSelectAll),
                      child: Text(allSelected ? '선택 해제' : '전체 선택'),
                    ),
                  ],
                  const Spacer(),
                  if (onDelete != null)
                    IconButton(
                      tooltip: '삭제',
                      onPressed: busy ? null : onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: busy ? null : onDownload,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: const Text('다운로드'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '취소',
                    onPressed: busy ? null : onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
