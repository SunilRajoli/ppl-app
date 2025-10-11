import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? token; // from query param
  const VerifyEmailScreen({super.key, this.token});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _api = ApiService();
  String _status = 'loading'; // loading | success | error
  String _msg = 'Verifying your email...';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _status = 'error';
        _msg = 'Invalid verification link.';
      });
      return;
    }

    try {
      await _api.verifyEmail(token);
      if (!mounted) return;
      setState(() {
        _status = 'success';
        _msg = 'Your email has been verified. You can safely close this tab and log in to your account.';
      });
      _timer = Timer(const Duration(seconds: 5), () {
        if (mounted) context.go('/');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _msg = e.toString().replaceFirst('ApiException', '').trim();
      });
    }
  }

  Future<void> _resend() async {
    try {
      await _api.resendVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent. Check your inbox.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;

    if (_status == 'loading') {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40, height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 12),
          Text(_msg, textAlign: TextAlign.center),
        ],
      );
    } else if (_status == 'success') {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('Email verified', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_msg, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Redirecting to our website…', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Go to Login'),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('❌', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('Verification failed', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_msg, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to home'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _resend,
                  child: const Text('Resend link'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
