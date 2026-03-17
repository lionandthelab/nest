import 'package:flutter/material.dart';

import '../nest_theme.dart';

/// Shimmer-style skeleton placeholder for loading states.
class NestSkeleton extends StatefulWidget {
  const NestSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<NestSkeleton> createState() => _NestSkeletonState();
}

class _NestSkeletonState extends State<NestSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: const [
                Color(0xFFEDE6DF),
                Color(0xFFF7F0EA),
                Color(0xFFEDE6DF),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A skeleton card that mimics a typical content card during loading.
class NestSkeletonCard extends StatelessWidget {
  const NestSkeletonCard({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                NestSkeleton(width: 40, height: 40, borderRadius: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NestSkeleton(height: 14),
                      SizedBox(height: 8),
                      NestSkeleton(width: 120, height: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < lines; i++) ...[
              NestSkeleton(
                height: 12,
                width: i == lines - 1 ? 180 : null,
              ),
              if (i < lines - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// A list of skeleton cards for full-screen loading states.
class NestSkeletonList extends StatelessWidget {
  const NestSkeletonList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => const NestSkeletonCard(),
    );
  }
}

/// Skeleton layout for metric summary cards.
class NestSkeletonMetrics extends StatelessWidget {
  const NestSkeletonMetrics({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        count,
        (_) => Container(
          constraints: const BoxConstraints(minWidth: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NestColors.roseMist),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NestSkeleton(width: 32, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NestSkeleton(width: 60, height: 10),
                  SizedBox(height: 6),
                  NestSkeleton(width: 40, height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
