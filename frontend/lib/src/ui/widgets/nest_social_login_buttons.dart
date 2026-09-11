import 'package:flutter/material.dart';
import 'package:lion_auth/lion_auth.dart';

import '../nest_theme.dart';
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
    final spec = switch (provider) {
      LionAuthProviderId.google => (
        color: Colors.white,
        border: const Color(0xFF747775),
        child: Text(
          'G',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF4285F4),
            fontWeight: FontWeight.w800,
          ),
        ),
        label: 'Google로 로그인',
      ),
      LionAuthProviderId.kakao => (
        color: const Color(0xFFFEE500),
        border: null,
        child: Text(
          '카',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: NestColors.deepWood,
            fontWeight: FontWeight.w800,
          ),
        ),
        label: '카카오로 로그인',
      ),
      LionAuthProviderId.naver => (
        color: const Color(0xFF03C75A),
        border: null,
        child: Text(
          'N',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
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
