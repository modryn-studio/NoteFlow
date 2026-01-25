import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Breathing circle animation for voice capture
class BreathingCircle extends StatefulWidget {
  final bool isActive;
  final double size;
  final Color color;

  const BreathingCircle({
    super.key,
    this.isActive = true,
    this.size = 200,
    this.color = AppColors.softLavender,
  });

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // 60 BPM = 1 breath per second
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BreathingCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
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
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color.withOpacity(_opacityAnimation.value),
                  widget.color.withOpacity(_opacityAnimation.value * 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(_opacityAnimation.value * 0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.4,
                height: widget.size * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.9),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: widget.size * 0.2,
                  color: AppColors.deepIndigo,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Simple waveform visualization
class WaveformVisualizer extends StatefulWidget {
  final bool isActive;
  final double height;
  final Color color;
  final int barCount;

  const WaveformVisualizer({
    super.key,
    this.isActive = true,
    this.height = 60,
    this.color = AppColors.softLavender,
    this.barCount = 30,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();
  List<double> _heights = [];

  @override
  void initState() {
    super.initState();
    _heights = List.generate(widget.barCount, (_) => _random.nextDouble());

    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    if (widget.isActive) {
      _controller.repeat();
    }

    _controller.addListener(_updateHeights);
  }

  void _updateHeights() {
    if (widget.isActive) {
      setState(() {
        for (int i = 0; i < _heights.length; i++) {
          _heights[i] = 0.2 + _random.nextDouble() * 0.8;
        }
      });
    }
  }

  @override
  void didUpdateWidget(WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      setState(() {
        _heights = List.generate(widget.barCount, (_) => 0.2);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.barCount, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: widget.height * _heights[index],
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
