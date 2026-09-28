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
    this.badgeText,
  });

  final String id;
  final HomeschoolTipTheme theme;
  final IconData icon;
  final String title;
  final String body;
  final String? badgeText;

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
      id: 'family-pace',
      theme: HomeschoolTipTheme.together,
      icon: Icons.favorite_outline,
      title: '우리 가족만의 속도로',
      body: '다른 집과 비교하지 않아도 괜찮아요. 우리 아이에게 맞는 편안한 속도가 가장 좋은 배움의 길이에요.',
    ),
    HomeschoolTip(
      id: 'daily-learning',
      theme: HomeschoolTipTheme.start,
      icon: Icons.eco_outlined,
      title: '일상의 모든 순간이 배움이에요',
      body: '요리와 장보기, 자연 산책 같은 소소한 하루도 아이에게는 훌륭한 홈스쿨 수업이 됩니다.',
    ),
    HomeschoolTip(
      id: 'simple-record',
      theme: HomeschoolTipTheme.record,
      icon: Icons.photo_camera_outlined,
      title: '작은 기록 하나면 충분해요',
      body: '거창한 보고서 대신 사진 한 장과 짧은 메모만 남겨도 소중한 성장의 흔적이 돼요.',
    ),
    HomeschoolTip(
      id: 'portfolio-preview',
      theme: HomeschoolTipTheme.record,
      icon: Icons.auto_awesome_outlined,
      badgeText: '준비 중',
      title: '아이의 성장을 담는 포트폴리오',
      body: '차곡차곡 모인 시간표와 활동 기록으로 학기 말 맞춤 학습 포트폴리오를 만들어 드리는 기능이 곧 추가됩니다.',
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
