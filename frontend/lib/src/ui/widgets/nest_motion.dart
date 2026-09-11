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
            color: selected
                ? NestColors.roseMist
                : NestColors.roseMist.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedScale(
            scale: selected ? 1 : 0.92,
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

Future<T?> showNestSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  NestHaptics.light();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    useSafeArea: true,
    barrierColor: NestColors.deepWood.withValues(alpha: 0.28),
    backgroundColor: Colors.white,
    builder: builder,
  );
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
