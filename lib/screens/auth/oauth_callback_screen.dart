import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';

class OAuthCallbackScreen extends StatefulWidget {
  const OAuthCallbackScreen({super.key});

  @override
  State<OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends State<OAuthCallbackScreen> {
  final _api = ApiService();
  String _status = 'loading'; // loading | success | error
  String _message = 'Processing authentication...';

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      // Get URL parameters
      final uri = GoRouterState.of(context).uri;
      final params = uri.queryParameters;

      // Check for error from OAuth provider
      final error = params['error'];
      if (error != null) {
        throw Exception(Uri.decodeComponent(error));
      }

      // Get token and provider from URL
      final token = params['token'];
      final provider = params['provider'];

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token received');
      }

      if (provider == null || provider.isEmpty) {
        throw Exception('No provider information received');
      }

      setState(() {
        _status = 'loading';
        _message = 'Exchanging OAuth code for session...';
      });

      // Exchange OAuth code for JWT token
      final result = await _api.exchangeOAuthCode(
        code: token, // The backend sends the token directly
        provider: provider,
      );

      if (result['success'] == true) {
        final data = result['data'] ?? result;
        final jwtToken = data['token'] as String?;
        final userJson = data['user'];

        if (jwtToken == null || userJson == null) {
          throw Exception('Invalid OAuth response');
        }

        // Save token and user using AuthProvider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setTokenAndUser(jwtToken, userJson);

        setState(() {
          _status = 'success';
          _message = 'Authentication successful! Redirecting...';
        });

        // Redirect based on user role
        final userRole = userJson['role']?.toString().toLowerCase();
        final isAdmin = userRole == 'admin';
        
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          final destination = isAdmin ? '/admin' : '/main';
          context.go('$destination?tab=competitions');
        }
      } else {
        throw Exception(result['message'] ?? 'OAuth authentication failed');
      }
    } catch (e) {
      setState(() {
        _status = 'error';
        _message = 'Authentication failed: ${e.toString()}';
      });

      // Auto-redirect to login after error
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _status == 'success' 
                        ? Colors.green.withOpacity(0.1)
                        : _status == 'error'
                            ? Colors.red.withOpacity(0.1)
                            : theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _status == 'success'
                        ? Icons.check_circle
                        : _status == 'error'
                            ? Icons.error
                            : Icons.autorenew,
                    size: 40,
                    color: _status == 'success'
                        ? Colors.green
                        : _status == 'error'
                            ? Colors.red
                            : theme.colorScheme.primary,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Status Message
                Text(
                  _message,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Loading indicator
                if (_status == 'loading') ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ],
                
                // Error actions
                if (_status == 'error') ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Try Again'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go Home'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
