import 'package:flutter/material.dart';

import '../../../services/album_organizer.dart';
import '../../widgets/search_select_field.dart';

/// 보기 방식의 사용자 대면 라벨·설명·아이콘.
///
/// 같은 목록을 네 가지로 보여 준다. 사진첩에는 "찾으러 오는" 사람과 "훑어보러
/// 오는" 사람이 섞여 있어서, 한 레이아웃으로는 둘 다 나빠진다.
extension AlbumViewModeLabels on AlbumViewMode {
  String get label => switch (this) {
    AlbumViewMode.grid => '격자',
    AlbumViewMode.timeline => '타임라인',
    AlbumViewMode.folder => '앨범',
    AlbumViewMode.large => '크게 보기',
  };

  String get description => switch (this) {
    AlbumViewMode.grid => '한 화면에 가장 많이 봅니다.',
    AlbumViewMode.timeline => '날짜별로 묶어서 봅니다.',
    AlbumViewMode.folder => '학기·수업별 폴더로 모아서 봅니다.',
    AlbumViewMode.large => '한 장씩 크게, 설명까지 봅니다.',
  };

  IconData get icon => switch (this) {
    AlbumViewMode.grid => Icons.grid_view_rounded,
    AlbumViewMode.timeline => Icons.view_day_outlined,
    AlbumViewMode.folder => Icons.photo_album_outlined,
    AlbumViewMode.large => Icons.crop_original_rounded,
  };

  /// 캐시에 저장할 값. enum 이름이 바뀌어도 저장값은 그대로 두려고 따로 둔다.
  String get storageKey => name;
}

AlbumViewMode albumViewModeFromKey(String? key, {AlbumViewMode? fallback}) {
  for (final mode in AlbumViewMode.values) {
    if (mode.storageKey == key) {
      return mode;
    }
  }
  return fallback ?? AlbumViewMode.grid;
}

Future<AlbumViewMode?> showAlbumViewModeSheet({
  required BuildContext context,
  required AlbumViewMode current,
}) {
  return showSelectSheet<AlbumViewMode>(
    context: context,
    title: '보기 방식',
    helpText: '사진을 어떻게 볼지 고르세요.',
    currentValue: current,
    options: [
      for (final mode in AlbumViewMode.values)
        SelectSheetOption(
          value: mode,
          title: mode.label,
          subtitle: mode.description,
        ),
    ],
  );
}
