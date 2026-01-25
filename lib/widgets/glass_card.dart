import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Glassmorphic card widget with frosted glass effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? glowColor;
  final double glowIntensity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.glowColor,
    this.glowIntensity = 0.0,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasGlow = glowColor != null && glowIntensity > 0;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: AppAnimations.standard,
          curve: AppAnimations.defaultCurve,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              // Main shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              // Glow effect for frequency indicators
              if (hasGlow)
                BoxShadow(
                  color: glowColor!.withOpacity(glowIntensity * 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: padding ?? const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.glassGradient,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: AppColors.glassHighlight.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated glass card with scale effect on tap
class AnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? glowColor;
  final double glowIntensity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AnimatedGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.glowColor,
    this.glowIntensity = 0.0,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GlassCard(
          padding: widget.padding,
          margin: widget.margin,
          borderRadius: widget.borderRadius,
          glowColor: widget.glowColor,
          glowIntensity: widget.glowIntensity,
          child: widget.child,
        ),
      ),
    );
  }
}
