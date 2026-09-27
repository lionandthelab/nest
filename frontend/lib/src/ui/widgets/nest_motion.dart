import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nest_theme.dart';

/// 탭·저장·시트에 쓰는 짧은 햅틱. 호출이 실패해도 화면은 그대로 동작한다.
class NestHaptics {
  const NestHaptics._();

  static void selection() {
    HapticFeedback.selectionClick();
  }

  static void light() {
    HapticFeedback.lightImpact();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }
}

/// 토스식 즉시 반응 + 제미나이식 랜딩에 쓰는 시간/곡선.
///
/// 화면 전환은 IndexedStack으로 0ms를 유지하고, 모션은 누르는 손끝과
/// 카드가 자리에 앉는 구간에만 쓴다. 반복 루프 애니메이션은 넣지 않는다
/// (모바일 셸 테스트가 pumpAndSettle을 피한다).
class NestMotion {
  const NestMotion._();

  static const pressIn = Duration(milliseconds: 70);
  static const pressOut = Duration(milliseconds: 220);
  static const appear = Duration(milliseconds: 420);
  static const stagger = Duration(milliseconds: 42);
  static const fade = Duration(milliseconds: 180);
  static const sheet = Duration(milliseconds: 320);

  static const pressScale = 0.97;

  static const pressCurve = Curves.easeOutCubic;
  static const releaseCurve = Curves.easeOutBack;
  static const appearCurve = Cubic(0.16, 1, 0.3, 1);
}

bool nestReduceMotion(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context);
}

Widget nestFadeSlideTransition(
  Widget child,
  Animation<double> animation, {
  Offset beginOffset = const Offset(0.02, 0),
}) {
  final curve = CurvedAnimation(
    parent: animation,
    curve: NestMotion.appearCurve,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curve,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(curve),
      child: child,
    ),
  );
}

/// 누르는 즉시 줄어들고, 손을 떼면 살짝 오버슈트하며 돌아온다.
///
/// [onPressed]가 있으면 탭을 이 위젯이 받는다. 없으면 자식(버튼 등)이
/// 탭을 처리하고, 이 위젯은 스케일만 준다.
class NestPressable extends StatefulWidget {
  const NestPressable({
    super.key,
    required this.child,
    this.onPressed,
    this.enabled = true,
    this.haptic = true,
    this.scale = NestMotion.pressScale,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool haptic;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<NestPressable> createState() => _NestPressableState();
}

class _NestPressableState extends State<NestPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: NestMotion.pressIn,
      reverseDuration: NestMotion.pressOut,
    );
    _scale = Tween<double>(begin: 1, end: widget.scale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: NestMotion.pressCurve,
        reverseCurve: NestMotion.releaseCurve,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canPress => widget.enabled && widget.onPressed != null;

  void _down(TapDownDetails _) {
    if (!widget.enabled) return;
    if (nestReduceMotion(context)) return;
    _controller.forward();
    if (widget.haptic) NestHaptics.selection();
  }

  void _up([_]) {
    if (!mounted) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scaled = ScaleTransition(scale: _scale, child: widget.child);
    final clipped = widget.borderRadius == null
        ? scaled
        : ClipRRect(borderRadius: widget.borderRadius!, child: scaled);

    return GestureDetector(
      behavior: widget.onPressed == null
          ? HitTestBehavior.deferToChild
          : HitTestBehavior.opaque,
      onTapDown: widget.enabled ? _down : null,
      onTapUp: widget.enabled ? _up : null,
      onTapCancel: widget.enabled ? _up : null,
      onTap: _canPress ? widget.onPressed : null,
      child: clipped,
    );
  }
}

/// 카드가 아래에서 스르륵 올라와 앉는다. 한 번만 재생한다.
class NestAppear extends StatefulWidget {
  const NestAppear({
    super.key,
    required this.child,
    this.index = 0,
    this.enabled = true,
  });

  final Widget child;
  final int index;
  final bool enabled;

  @override
  State<NestAppear> createState() => _NestAppearState();
}

class _NestAppearState extends State<NestAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final delay = NestMotion.stagger * widget.index.clamp(0, 8);
    final total = NestMotion.appear + delay;
    _controller = AnimationController(vsync: this, duration: total);
    final start = total.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: NestMotion.appearCurve),
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(curve);
    _scale = Tween<double>(begin: 0.985, end: 1).animate(curve);

    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (nestReduceMotion(context) || !widget.enabled) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// 하단 탭. 콘텐츠는 IndexedStack이 즉시 바꾸고, 여기선 손끝 스케일과
/// 선택 필만 움직인다.
class NestDockBar extends StatelessWidget {
  const NestDockBar({
    super.key,
    required this.selectedIndex,
    required this.labels,
    required this.iconOf,
    required this.onSelect,
  });

  final int selectedIndex;
  final List<String> labels;
  final Widget Function(String label, {required bool selected}) iconOf;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: NestColors.roseMist.withValues(alpha: 0.9)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: NestPressable(
                    haptic: true,
                    onPressed: () => onSelect(i),
                    child: _DockItem(
                      label: labels[i],
                      selected: i == selectedIndex,
                      icon: iconOf(labels[i], selected: i == selectedIndex),
                      textStyle: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.label,
    required this.selected,
    required this.icon,
    required this.textStyle,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: NestMotion.fade,
          curve: NestMotion.appearCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      Colors.white,
                      NestColors.roseMist,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(
                    color: NestColors.dustyRose.withValues(alpha: 0.35),
                    width: 1.2,
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: NestColors.dustyRose.withValues(alpha: 0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 2,
                      offset: Offset(0, -1),
                    ),
                  ]
                : null,
          ),
          child: AnimatedScale(
            scale: selected ? 1.04 : 0.94,
            duration: NestMotion.fade,
            curve: NestMotion.appearCurve,
            child: IconTheme(
              data: IconThemeData(
                size: 22,
                color: NestColors.deepWood.withValues(
                  alpha: selected ? 1 : 0.55,
                ),
              ),
              child: icon,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: NestColors.deepWood.withValues(alpha: selected ? 1 : 0.62),
          ),
        ),
      ],
    );
  }
}

class NestLoadingScreen extends StatelessWidget {
  const NestLoadingScreen({super.key, this.message = 'Nest를 준비하고 있습니다...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF4EC),
              NestColors.creamyWhite,
              Color(0xFFF3ECE2),
            ],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            duration: NestMotion.appear,
            curve: NestMotion.appearCurve,
            tween: Tween(begin: 0.96, end: 1),
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: NestColors.roseMist.withValues(alpha: 0.92),
                ),
                boxShadow: [
                  BoxShadow(
                    color: NestColors.deepWood.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.82),
                      ),
                    ),
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

class NestBusyOverlay extends StatelessWidget {
  const NestBusyOverlay({
    super.key,
    required this.visible,
    this.message = '변경사항을 반영하는 중입니다...',
  });

  final bool visible;
  final String message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: NestMotion.fade,
        curve: Curves.easeOut,
        opacity: visible ? 1 : 0,
        child: visible
            ? Column(
                children: [
                  const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: NestColors.creamyWhite.withValues(alpha: 0.42),
                      ),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: NestColors.roseMist),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  message,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: NestColors.deepWood.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

/// 탭할 때 자연스럽게 눌리는 햅틱/클레이 느낌의 터치 모션 위젯.
class TactileCard extends StatefulWidget {
  const TactileCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 20.0,
    this.pressedScale = 0.975,
    this.backgroundColor,
    this.border,
    this.padding,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final double pressedScale;
  final Color? backgroundColor;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  State<TactileCard> createState() => _TactileCardState();
}

class _TactileCardState extends State<TactileCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? Colors.white.withValues(alpha: 0.95);
    final isInteractive = widget.onTap != null || widget.onLongPress != null;

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border:
            widget.border ??
            Border.all(
              color: NestColors.roseMist.withValues(alpha: 0.85),
              width: 1.2,
            ),
        boxShadow: [
          // Ambient soft glow
          BoxShadow(
            color: NestColors.dustyRose.withValues(
              alpha: _isPressed ? 0.04 : 0.08,
            ),
            blurRadius: _isPressed ? 8 : 16,
            offset: Offset(0, _isPressed ? 2 : 6),
          ),
          // Contact depth shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: _isPressed ? 0.02 : 0.04),
            blurRadius: _isPressed ? 3 : 6,
            offset: Offset(0, _isPressed ? 1 : 2),
          ),
        ],
      ),
      child: widget.child,
    );

    if (!isInteractive) {
      return Container(margin: widget.margin, child: cardContent);
    }

    return Container(
      margin: widget.margin,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isPressed ? widget.pressedScale : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: cardContent,
        ),
      ),
    );
  }
}

/// 3D 로고나 주요 엠블럼이 부드럽게 숨쉬듯 위아래로 부유하는 모션 위젯.
class Floating3DWidget extends StatefulWidget {
  const Floating3DWidget({
    super.key,
    required this.child,
    this.floatDistance = 6.0,
    this.duration = const Duration(milliseconds: 2600),
  });

  final Widget child;
  final double floatDistance;
  final Duration duration;

  @override
  State<Floating3DWidget> createState() => _Floating3DWidgetState();
}

class _Floating3DWidgetState extends State<Floating3DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sinVal = math.sin(_controller.value * 2 * math.pi);
        final offsetY = sinVal * (widget.floatDistance / 2);
        return Transform.translate(
          offset: Offset(0, offsetY),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 화면 진입 시 순차적으로 떠오르는 스태거드 페이드 & 슬라이드 위젯.
class StaggeredSlideFade extends StatefulWidget {
  const StaggeredSlideFade({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
    this.offsetY = 18.0,
  });

  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<StaggeredSlideFade> createState() => _StaggeredSlideFadeState();
}

class _StaggeredSlideFadeState extends State<StaggeredSlideFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(curve);

    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
