import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

/// Splash screen that handles auto-authentication
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Small delay for splash animation
      await Future.delayed(const Duration(milliseconds: 800));

      setState(() {
        _statusMessage = 'Signing in...';
      });

      // Ensure user is authenticated
      await AuthService.instance.ensureAuthenticated();

      setState(() {
        _statusMessage = 'Loading notes...';
      });

      await Future.delayed(const Duration(milliseconds: 400));

      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo/icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.softLavender,
                              AppColors.softTeal,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.softLavender.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          size: 60,
                          color: AppColors.deepIndigo,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // App name
                      Text(
                        'NoteFlow',
                        style: AppTypography.heading.copyWith(
                          fontSize: 36,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline
                      Text(
                        'Intelligent note surfacing',
                        style: AppTypography.caption.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Loading indicator
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.softLavender.withOpacity(0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status message
                      Text(
                        _statusMessage,
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
