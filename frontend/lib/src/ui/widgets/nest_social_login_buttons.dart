import 'package:flutter/material.dart';
import 'package:lion_auth/lion_auth.dart';

import '../nest_theme.dart';
import 'brand_marks.dart';
import 'nest_motion.dart';

/// lion_auth 버튼 API와 무관하게, Nest가 소셜 탭을 직접 받는다.
class NestSocialLoginButtons extends StatelessWidget {
  const NestSocialLoginButtons({
    super.key,
    required this.providers,
    required this.onSelect,
    this.enabled = true,
  });

  final List<LionAuthProviderId> providers;
  final Future<void> Function(LionAuthProviderId id) onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final id in providers)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: NestPressable(
              enabled: enabled,
              onPressed: enabled ? () => onSelect(id) : null,
              child: _BrandCircle(provider: id),
            ),
          ),
      ],
    );
  }
}

class _BrandCircle extends StatelessWidget {
  const _BrandCircle({required this.provider});

  final LionAuthProviderId provider;

  @override
  Widget build(BuildContext context) {
    // 배경·테두리 색과 로고는 각 사 브랜드 가이드를 따른다.
    // NestColors 로 바꾸면 안 되는 유일한 곳이다.
    final spec = switch (provider) {
      LionAuthProviderId.google => (
        color: Colors.white,
        border: const Color(0xFF747775),
        child: const GoogleMark(),
        label: 'Google로 로그인',
      ),
      LionAuthProviderId.kakao => (
        color: const Color(0xFFFEE500),
        border: null,
        child: const KakaoMark(),
        label: '카카오로 로그인',
      ),
      LionAuthProviderId.naver => (
        color: const Color(0xFF03C75A),
        border: null,
        child: const NaverMark(),
        label: '네이버로 로그인',
      ),
      LionAuthProviderId.apple => (
        color: NestColors.deepWood,
        border: null,
        child: const Icon(Icons.apple, color: Colors.white, size: 26),
        label: 'Apple로 로그인',
      ),
    };

    return Tooltip(
      message: spec.label,
      child: Semantics(
        button: true,
        label: spec.label,
        child: Material(
          color: spec.color,
          elevation: 1,
          shape: CircleBorder(
            side: spec.border == null
                ? BorderSide.none
                : BorderSide(color: spec.border!),
          ),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(child: spec.child),
          ),
        ),
      ),
    );
  }
}
