import 'package:flutter/material.dart';

import '../nest_theme.dart';

/// Branded pull-to-refresh wrapper using Nest color scheme.
class NestRefreshable extends StatelessWidget {
  const NestRefreshable({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: NestColors.dustyRose,
      backgroundColor: Colors.white,
      displacement: 40,
      strokeWidth: 2.5,
      child: child,
    );
  }
}
