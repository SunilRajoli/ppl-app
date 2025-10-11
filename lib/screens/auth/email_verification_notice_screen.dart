import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';

class EmailVerificationNoticeScreen extends StatefulWidget {
  final String? initialEmail;
  const EmailVerificationNoticeScreen({super.key, this.initialEmail});

  @override
  State<EmailVerificationNoticeScreen> createState() => _EmailVerificationNoticeScreenState();
}

class _EmailVerificationNoticeScreenState extends State<EmailVerificationNoticeScreen> {
  final _emailCtrl = TextEditingController();
  final _api = ApiService();

  String _msg = 'We sent a verification link to your email.';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialEmail ?? '').isNotEmpty) {
      _emailCtrl.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _busy = true;
      _msg = 'Sending verification email...';
    });
    try {
      final res = await _api.resendVerificationPublic(email);
      final m = (res is Map && res['message'] != null)
          ? res['message'].toString()
          : 'Verification email sent. Check your inbox.';
      setState(() => _msg = m);
    } catch (e) {
      setState(() => _msg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openMailApp() {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.endsWith('@gmail.com')) {
      GoRouter.of(context).push(Uri.parse('https://mail.google.com').toString());
    } else if (RegExp(r'@(outlook|hotmail)\.com$').hasMatch(email)) {
      GoRouter.of(context).push(Uri.parse('https://outlook.live.com').toString());
    } else {
      // fallback
      GoRouter.of(context).push(Uri.parse('mailto:$email').toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📫', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text('Check your email', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(_msg, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'your@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_busy || _emailCtrl.text.trim().isEmpty) ? null : _resend,
                            child: Text(_busy ? 'Sending...' : 'Resend link'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _emailCtrl.text.trim().isEmpty ? null : _openMailApp,
                            child: const Text('Open email'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already verified? Log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
