import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Shimmer animation widget for tag assignment feedback
class TagShimmer extends StatefulWidget {
  final Widget child;
  final bool animate;
  final Duration duration;

  const TagShimmer({
    super.key,
    required this.child,
    this.animate = true,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<TagShimmer> createState() => _TagShimmerState();
}

class _TagShimmerState extends State<TagShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(TagShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.animate
                ? [
                    BoxShadow(
                      color: AppColors.softLavender
                          .withValues(alpha: 0.5 * (1 - _shimmerAnimation.value)),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Tag chip with optional shimmer effect
class TagChip extends StatelessWidget {
  final String label;
  final bool isNew;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const TagChip({
    super.key,
    required this.label,
    this.isNew = false,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final chip = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.softLavender.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.softLavender.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.tag,
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.softLavender,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isNew) {
      return TagShimmer(
        animate: true,
        child: chip,
      );
    }

    return chip;
  }
}
