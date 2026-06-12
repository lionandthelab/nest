import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wraps a horizontally-scrolling [child] so that a vertical mouse wheel drives
/// the horizontal offset.
///
/// Flutter does not natively map a vertical mouse wheel (which only emits on the
/// vertical axis) onto a horizontal [SingleChildScrollView], so desktop mouse
/// users cannot scroll wide boards. Trackpads already emit a horizontal delta
/// and keep working untouched; only a *pure* vertical wheel is translated. A
/// thin always-visible scrollbar is shown for affordance.
class HorizontalMouseScroll extends StatefulWidget {
  const HorizontalMouseScroll({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  State<HorizontalMouseScroll> createState() => _HorizontalMouseScrollState();
}

class _HorizontalMouseScrollState extends State<HorizontalMouseScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;
    // Trackpad horizontal gestures already carry a horizontal delta and are
    // handled natively by the scroll view — leave them alone. Only a pure
    // vertical mouse wheel (dx == 0) is translated to horizontal motion.
    if (event.scrollDelta.dx != 0) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;

    final position = _controller.position;
    final target = (_controller.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != _controller.offset) {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
