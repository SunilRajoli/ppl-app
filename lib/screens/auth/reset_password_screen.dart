import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  /// Optional: allow passing the token directly when navigating with state.extra.
  final String? token;
  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _success = false;
  String? _message;
  String? _token;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final _api = ApiService();

  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();

    // 1) token via URL (web/universal links)
    _token = Uri.base.queryParameters['token'];

    // 2) or via widget arg (when you push with state.extra)
    _token ??= widget.token;

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );

    _anim.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _anim.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Use 6+ characters';
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (pass != confirm) {
      setState(() {
        _success = false;
        _message = 'Passwords do not match';
      });
      return;
    }

    if (_token == null || _token!.isEmpty) {
      setState(() {
        _success = false;
        _message = 'Missing reset token. Use the link sent to your email.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result =
          await _api.resetPassword(token: _token!, newPassword: pass);

      final ok = result['success'] == true;
      final msg = result['message'] as String? ??
          (ok
              ? 'Password reset successful. Redirecting to login…'
              : 'Reset failed. The token may be invalid or expired.');

      if (!mounted) return;
      setState(() {
        _success = ok;
        _message = msg;
      });

      if (ok) {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        context.go('/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = 'Network error: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _smartBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/forgot-password');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 18,
                          offset: Offset(0, 8),
                          color: Color(0x14000000),
                        )
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header: Back + Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: _loading ? null : _smartBack,
                                icon: const Icon(Icons.arrow_back, size: 20),
                                label: const Text('Back'),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      theme.colorScheme.onSurfaceVariant,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  textStyle:
                                      theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Icon(Icons.vpn_key_rounded,
                                    color: theme.colorScheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Set a new password',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // New password (native TextFormField for autofill/action)
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure1,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'New password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure1 = !_obscure1),
                                icon: Icon(
                                    _obscure1 ? Icons.visibility : Icons.visibility_off),
                                tooltip: _obscure1 ? 'Show' : 'Hide',
                              ),
                            ),
                            validator: _validatePassword,
                          ),

                          const SizedBox(height: 12),

                          // Confirm password
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscure2,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _handleSubmit(),
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure2 = !_obscure2),
                                icon: Icon(
                                    _obscure2 ? Icons.visibility : Icons.visibility_off),
                                tooltip: _obscure2 ? 'Show' : 'Hide',
                              ),
                            ),
                            validator: (v) {
                              final err = _validatePassword(v);
                              if (err != null) return err;
                              if (v != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // Banner
                          if (_message != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _success
                                    ? (isDark
                                        ? Colors.green.shade900
                                        : Colors.green.shade50)
                                    : (isDark
                                        ? Colors.red.shade900
                                        : Colors.red.shade50),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _success
                                      ? (isDark
                                          ? Colors.green.shade700
                                          : Colors.green.shade200)
                                      : (isDark
                                          ? Colors.red.shade700
                                          : Colors.red.shade200),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _success
                                        ? Icons.verified_user
                                        : Icons.error_outline,
                                    size: 20,
                                    color: _success
                                        ? (isDark
                                            ? Colors.green.shade300
                                            : Colors.green.shade700)
                                        : (isDark
                                            ? Colors.red.shade300
                                            : Colors.red.shade700),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: _success
                                            ? (isDark
                                                ? Colors.green.shade200
                                                : Colors.green.shade700)
                                            : (isDark
                                                ? Colors.red.shade200
                                                : Colors.red.shade700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Submit button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _loading ? 'Saving…' : 'Save new password',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Back to Login
                          Align(
                            alignment: Alignment.center,
                            child: TextButton.icon(
                              onPressed:
                                  _loading ? null : () => context.go('/login'),
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Back to Login'),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
