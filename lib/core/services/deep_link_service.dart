import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> initialize(BuildContext context) async {
    // Handle initial link if app was opened from terminated state
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(context, initialLink);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

    // Handle links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(context, uri),
      onError: (err) => debugPrint('Deep link error: $err'),
    );
  }

  void _handleDeepLink(BuildContext context, Uri uri) {
    debugPrint('📱 Deep link received: $uri');

    final path = uri.path;
    final params = uri.queryParameters;

    // Handle verification email
    if (path == '/verify-email' || path.endsWith('/verify-email')) {
      final token = params['token'];
      if (token != null) {
        context.go('/verify-email?token=$token');
        return;
      }
    }

    // Handle password reset
    if (path == '/reset-password' || path.endsWith('/reset-password')) {
      final token = params['token'];
      if (token != null) {
        context.go('/reset-password?token=$token');
        return;
      }
    }

    // Handle OAuth callback
    if (path == '/oauth-callback' || path.endsWith('/oauth-callback')) {
      final token = params['token'];
      final provider = params['provider'];
      if (token != null && provider != null) {
        context.go('/oauth-callback?token=$token&provider=$provider');
        return;
      }
    }

    // Add more deep link handlers as needed
    debugPrint('⚠️  Unhandled deep link path: $path');
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}