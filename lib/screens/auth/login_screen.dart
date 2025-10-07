import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../widgets/custom_widgets.dart'; // for LoadingButton (we won't use CustomTextField)

class LoginScreen extends StatefulWidget {
  final String? role; // 'student' | 'hiring' | 'investor' | 'admin'

  const LoginScreen({super.key, this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _rememberMe = true; // UI only, not passed to provider (provider doesn't support it)

  bool _isLoading = false;
  bool _oauthLoading = false;
  String? _errorMessage;

  late final AnimationController _anim;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool get _busy => _isLoading || _oauthLoading;

  void _smartBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/'); // fallback
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        role: widget.role, // keep passing role if your backend supports it
        // rememberMe: (removed) — your provider doesn't support it
      );

      if (!mounted) return;

      if (result['success'] == true) {
        if (result['mustChangePassword'] == true) {
          context.go('/change-password');
          return;
        }
        final dest = auth.isAdmin ? '/admin' : '/main';
        context.go('$dest?tab=competitions');
      } else {
        setState(() => _errorMessage = result['message'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOAuthLoginGoogle() async {
    setState(() {
      _oauthLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _api.getGoogleAuthUrl();
      final authUrl = res['data']?['authUrl']?.toString() ?? res['authUrl']?.toString();
      if (authUrl == null || authUrl.isEmpty) throw Exception('Failed to get OAuth URL');
      final uri = Uri.parse(authUrl);
      if (!await canLaunchUrl(uri)) throw Exception('Could not open Google login');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initiate Google login: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _oauthLoading = false);
    }
  }

  IconData _roleIcon(String r) {
    switch (r.toLowerCase()) {
      case 'admin':
        return Icons.shield_outlined;
      case 'hiring':
        return Icons.badge_outlined;
      case 'investor':
        return Icons.trending_up;
      default:
        return Icons.school;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final role = widget.role?.toLowerCase();
    final showOAuth = role != 'admin'; // no OAuth for admin
    final canPop = GoRouter.of(context).canPop() || Navigator.of(context).canPop();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _smartBack();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: canPop,
            leading: canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _busy ? null : _smartBack,
                  )
                : null,
            title: const Text('Login'),
            actions: [
              if (role != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_roleIcon(role), size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          role.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.login, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome back', style: theme.textTheme.headlineMedium),
                                Text('Sign in to continue', style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onFieldSubmitted: (_) => _passFocus.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final v = (value ?? '').trim();
                            if (v.isEmpty) return 'Email is required';
                            final re = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$');
                            if (!re.hasMatch(v)) return 'Enter a valid email';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password with visibility toggle
                        TextFormField(
                          controller: _passCtrl,
                          focusNode: _passFocus,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _busy ? null : _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                              tooltip: _obscure ? 'Show' : 'Hide',
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Password is required';
                            if (value.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),

                        const SizedBox(height: 8),

                        // Remember + Forgot
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: _busy ? null : (v) => setState(() => _rememberMe = v ?? true),
                            ),
                            const Text('Remember me'),
                            const Spacer(),
                            TextButton(
                              onPressed: _busy ? null : () => context.push('/forgot-password'),
                              child: const Text('Forgot Password?'),
                            ),
                          ],
                        ),

                        // Error box
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.red.shade900 : Colors.red.shade50,
                              border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: isDark ? Colors.red.shade200 : Colors.red.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Login button
                        LoadingButton(
                          onPressed: _busy ? () {} : _handleLogin,
                          isLoading: _isLoading,
                          child: const Text('Login'),
                        ),

                        const SizedBox(height: 12),

                        // Register (hidden for admin)
                        if (role != 'admin')
                          Center(
                            child: TextButton(
                              onPressed: _busy ? null : () => context.push('/register', extra: {'role': role}),
                              child: RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodyMedium,
                                  children: [
                                    const TextSpan(text: "Don't have an account? "),
                                    TextSpan(
                                      text: 'Register',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // OAuth (non-admin only)
                        if (role != 'admin') ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('OR', style: theme.textTheme.bodySmall),
                              ),
                              Expanded(child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _oauthLoading ? null : _handleOAuthLoginGoogle,
                            icon: const Icon(Icons.g_mobiledata, size: 24),
                            label: Text(_oauthLoading ? 'Opening Google...' : 'Continue with Google'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            ),
                          ),
                        ],
                      ],
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
