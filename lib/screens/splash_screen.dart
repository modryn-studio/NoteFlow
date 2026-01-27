import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
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
  bool _hasError = false;
  String? _errorDetails;

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
    setState(() {
      _hasError = false;
      _errorDetails = null;
      _statusMessage = 'Initializing...';
    });

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
    } on AuthenticationException catch (e) {
      // Specific auth error - show friendly message with retry
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Authentication failed';
          _errorDetails = e.message;
        });
      }
    } catch (e) {
      // Generic error - could be network, server, etc.
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Connection failed';
          _errorDetails = _getErrorMessage(e);
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network') || errorString.contains('socket')) {
      return 'Please check your internet connection';
    } else if (errorString.contains('timeout')) {
      return 'Connection timed out. Please try again.';
    } else if (errorString.contains('auth')) {
      return 'Authentication failed. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _retry() {
    _initializeApp();
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
                              color: AppColors.softLavender.withValues(alpha: 0.4),
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

                      // Loading indicator or error icon
                      if (_hasError)
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 32,
                          color: AppColors.warmGlow.withValues(alpha: 0.8),
                        )
                      else
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.softLavender.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Status message
                      Text(
                        _statusMessage,
                        style: AppTypography.caption.copyWith(
                          color: _hasError ? AppColors.warmGlow : null,
                        ),
                      ),

                      // Error details
                      if (_hasError && _errorDetails != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            _errorDetails!,
                            style: AppTypography.caption.copyWith(
                              fontSize: 12,
                              color: AppColors.subtleGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Retry button
                        GestureDetector(
                          onTap: _retry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softLavender.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.softLavender.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: AppColors.softLavender,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Retry',
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.softLavender,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
