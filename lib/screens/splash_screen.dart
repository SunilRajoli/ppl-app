import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated) {
      if (authProvider.mustChangePassword) {
        context.go('/change-password');
      } else {
        final destination = authProvider.isAdmin ? '/admin' : '/main';
        context.go('$destination?tab=dashboard');
      }
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo - matches React version exactly
                Container(
                  width: 96, // w-24 = 96px
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1), // bg-primary/10
                    borderRadius: BorderRadius.circular(48), // rounded-full
                  ),
                  child: Center(
                    child: Container(
                      width: 48, // w-12 = 48px
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2), // bg-primary/20
                        borderRadius: BorderRadius.circular(12), // rounded-lg
                      ),
                      child: Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            fontSize: 24, // text-2xl
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32), // mb-8
                
                // Title - matches React version
                Text(
                  'PPL Platform',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 36, // text-4xl
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                
                const SizedBox(height: 8), // mb-2
                
                // Subtitle - matches React version
                Text(
                  'Student Projects League',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18, // text-lg
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
                
                const SizedBox(height: 32), // mb-8
                
                // Loading indicator - matches React version
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24, // h-6 w-6
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, // border-b-2
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // space-x-2
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 48), // mt-12
                
                // Tagline - matches React version
                Text(
                  'Where Student Projects Meet Real Investors',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14, // text-sm
                    color: theme.colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}