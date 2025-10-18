import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/providers/auth_provider.dart';
import '../screens/splash_screen.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _showSplash = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAndShowSplash();
  }

  Future<void> _checkAndShowSplash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenSplash = prefs.getBool('ppl-has-seen-splash') ?? false;
      final isFromLogout = prefs.getBool('ppl-from-logout') ?? false;
      
      if (!hasSeenSplash && !isFromLogout) {
        // Very first app load - show splash screen
        setState(() => _showSplash = true);
        
        // Mark that user has seen the splash screen
        await prefs.setBool('ppl-has-seen-splash', true);
        
        // Wait for splash duration then navigate
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          setState(() => _showSplash = false);
          _navigateBasedOnAuth();
        }
      } else {
        // Coming from refresh or logout - skip splash screen
        if (isFromLogout) {
          await prefs.remove('ppl-from-logout');
        }
        
        if (mounted) {
          _navigateBasedOnAuth();
        }
      }
    } catch (e) {
      // If there's an error, just navigate normally
      if (mounted) {
        _navigateBasedOnAuth();
      }
    }
  }

  void _navigateBasedOnAuth() {
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
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen();
    }
    
    // Return empty container while determining navigation
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
