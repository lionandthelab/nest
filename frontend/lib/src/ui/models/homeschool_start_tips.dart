/// 우리집 홈스쿨을 처음 여는 부모님을 위한 짧은 팁.
///
/// 법령·학력 인정·신고는 다루지 않는다.
library;

import 'package:flutter/material.dart';

enum HomeschoolTipTheme { start, rhythm, record, together }

class HomeschoolTip {
  const HomeschoolTip({
    required this.id,
    required this.theme,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String id;
  final HomeschoolTipTheme theme;
  final IconData icon;
  final String title;
  final String body;

  String get themeLabel => switch (theme) {
    HomeschoolTipTheme.start => '시작',
    HomeschoolTipTheme.rhythm => '리듬',
    HomeschoolTipTheme.record => '기록',
    HomeschoolTipTheme.together => '함께',
  };
}

class HomeschoolStartDefaults {
  const HomeschoolStartDefaults._();

  static const defaultName = '우리집 홈스쿨';
  static const defaultClassName = '우리 반';
  static const defaultCourses = '국어, 수학, 영어, 과학, 독서';

  static String nameFromProfile({
    String realName = '',
    String nickname = '',
  }) {
    final base = realName.trim().isNotEmpty
        ? realName.trim()
        : nickname.trim();
    if (base.isEmpty) return defaultName;
    if (base.contains('홈스쿨') || base.contains('둥지') || base.contains('집')) {
      return base;
    }
    final short = base.split(RegExp(r'\s+')).first;
    if (short.length > 8) return defaultName;
    return '$short네 집';
  }

  static String termName([DateTime? now]) {
    final date = now ?? DateTime.now();
    final season = switch (date.month) {
      >= 3 && <= 5 => '봄',
      >= 6 && <= 8 => '여름',
      >= 9 && <= 11 => '가을',
      _ => '겨울',
    };
    return '${date.year} $season 학기';
  }
}

class HomeschoolStartTips {
  const HomeschoolStartTips._();

  static const List<HomeschoolTip> all = [
    HomeschoolTip(
      id: 'one-thing',
      theme: HomeschoolTipTheme.start,
      icon: Icons.flag_outlined,
      title: '이번 주 한 가지만',
      body: '처음부터 학교처럼 안 짜도 돼요. 이번 주에 지킬 한 가지만 정하면 충분해요.',
    ),
    HomeschoolTip(
      id: 'same-time',
      theme: HomeschoolTipTheme.rhythm,
      icon: Icons.schedule,
      title: '같은 시간에 책상만 펴도',
      body: '매일 같은 시간에 책상만 펴도, 아이도 나도 몸이 먼저 알아요.',
    ),
    HomeschoolTip(
      id: 'living-classroom',
      theme: HomeschoolTipTheme.start,
      icon: Icons.kitchen_outlined,
      title: '부엌도 교실이에요',
      body: '장보기, 요리, 산책도 우리집 홈스쿨 수업으로 세어도 돼요.',
    ),
    HomeschoolTip(
      id: 'one-line',
      theme: HomeschoolTipTheme.record,
      icon: Icons.photo_outlined,
      title: '사진 한 장, 한 줄',
      body: '매일 보고서를 쓰지 않아도 돼요. 짧게 남기면 나중에 기록이 돼요.',
    ),
    HomeschoolTip(
      id: 'rest-day',
      theme: HomeschoolTipTheme.rhythm,
      icon: Icons.weekend_outlined,
      title: '쉬는 날을 미리',
      body: '쉬는 날을 정해 두면, 지키는 날이 오히려 편해져요.',
    ),
    HomeschoolTip(
      id: 'no-compare',
      theme: HomeschoolTipTheme.together,
      icon: Icons.favorite_outline,
      title: '우리집 속도로',
      body: '학교 진도와 맞출 필요 없어요. 우리집 속도가 곧 커리큘럼이에요.',
    ),
  ];

  /// 날짜가 바뀌면 다른 팁이 앞에 온다. 같은 날에는 항상 같은 팁이다.
  static HomeschoolTip tipOfTheDay([DateTime? now]) {
    final date = now ?? DateTime.now();
    final index =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(2026, 1, 1)).inDays.abs() %
        all.length;
    return all[index];
  }

  static List<HomeschoolTip> moreTips([DateTime? now]) {
    final featured = tipOfTheDay(now);
    return all.where((tip) => tip.id != featured.id).toList(growable: false);
  }
}
