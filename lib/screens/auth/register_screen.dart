// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../../core/providers/auth_provider.dart';
// import '../../core/services/api_service.dart';
// import '../../widgets/custom_widgets.dart'; // uses LoadingButton, CustomTextField

// class RegisterScreen extends StatefulWidget {
//   final String? role; // 'student' | 'hiring' | 'investor' | 'admin'

//   const RegisterScreen({super.key, this.role});

//   @override
//   State<RegisterScreen> createState() => _RegisterScreenState();
// }

// class _RegisterScreenState extends State<RegisterScreen> {
//   final _formKey = GlobalKey<FormState>();

//   // Common
//   final _nameCtrl = TextEditingController();
//   final _emailCtrl = TextEditingController();
//   final _passCtrl = TextEditingController();

//   // Student
//   final _collegeCtrl = TextEditingController();
//   final _branchCtrl = TextEditingController();
//   final _yearCtrl = TextEditingController();

//   // Hiring team
//   final _companyNameCtrl = TextEditingController();
//   final _companySiteCtrl = TextEditingController();
//   final _teamSizeCtrl = TextEditingController();

//   // Investor
//   final _firmNameCtrl = TextEditingController();
//   final _stageCtrl = TextEditingController();
//   final _firmSiteCtrl = TextEditingController();

//   // Focus chain (only for native TextFormField)
//   final _emailFocus = FocusNode();
//   final _passFocus = FocusNode();
//   final _extra1Focus = FocusNode();
//   final _extra2Focus = FocusNode();

//   bool _isLoading = false;
//   bool _oauthLoading = false;
//   bool _obscure = true;
//   bool _agree = false;
//   String? _error;

//   @override
//   void dispose() {
//     _nameCtrl.dispose();
//     _emailCtrl.dispose();
//     _passCtrl.dispose();

//     _collegeCtrl.dispose();
//     _branchCtrl.dispose();
//     _yearCtrl.dispose();

//     _companyNameCtrl.dispose();
//     _companySiteCtrl.dispose();
//     _teamSizeCtrl.dispose();

//     _firmNameCtrl.dispose();
//     _stageCtrl.dispose();
//     _firmSiteCtrl.dispose();

//     _emailFocus.dispose();
//     _passFocus.dispose();
//     _extra1Focus.dispose();
//     _extra2Focus.dispose();
//     super.dispose();
//   }

//   String get _role => (widget.role ?? 'student').toLowerCase();
//   bool get _isStudent => _role == 'student';
//   bool get _isHiring => _role == 'hiring';
//   bool get _isInvestor => _role == 'investor';
//   bool get _isAdmin => _role == 'admin';
//   bool get _busy => _isLoading || _oauthLoading;

//   IconData _roleIcon(String r) {
//     switch (r) {
//       case 'admin':
//         return Icons.shield_outlined;
//       case 'hiring':
//         return Icons.badge_outlined;
//       case 'investor':
//         return Icons.trending_up;
//       default:
//         return Icons.school;
//     }
//   }

//   void _smartBack() {
//     final r = GoRouter.of(context);
//     if (r.canPop()) {
//       r.pop();
//     } else if (Navigator.of(context).canPop()) {
//       Navigator.of(context).pop();
//     } else {
//       context.go('/');
//     }
//   }

//   Future<void> _handleRegister() async {
//     FocusScope.of(context).unfocus();
//     if (!_formKey.currentState!.validate()) return;

//     if (!_agree) {
//       setState(() => _error = 'Please agree to the Terms & Privacy.');
//       return;
//     }

//     // Admin is invite-only (guard)
//     if (_isAdmin) {
//       setState(() => _error = 'Admin accounts are invite-only. Please use an admin invite link.');
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });

//     try {
//       final auth = context.read<AuthProvider>();
//       final payload = <String, dynamic>{
//         'name': _nameCtrl.text.trim(),
//         'email': _emailCtrl.text.trim(),
//         'password': _passCtrl.text,
//         'role': _role,
//       };

//       if (_isStudent) {
//         if (_collegeCtrl.text.trim().isNotEmpty) payload['college'] = _collegeCtrl.text.trim();
//         if (_branchCtrl.text.trim().isNotEmpty) payload['branch'] = _branchCtrl.text.trim();
//         final y = int.tryParse(_yearCtrl.text.trim());
//         if (y != null) payload['year'] = y;
//       } else if (_isHiring) {
//         if (_companyNameCtrl.text.trim().isNotEmpty) payload['company_name'] = _companyNameCtrl.text.trim();
//         if (_companySiteCtrl.text.trim().isNotEmpty) payload['company_website'] = _companySiteCtrl.text.trim();
//         final ts = int.tryParse(_teamSizeCtrl.text.trim());
//         if (ts != null) payload['team_size'] = ts;
//       } else if (_isInvestor) {
//         if (_firmNameCtrl.text.trim().isNotEmpty) payload['firm_name'] = _firmNameCtrl.text.trim();
//         if (_stageCtrl.text.trim().isNotEmpty) payload['investment_stage'] = _stageCtrl.text.trim();
//         if (_firmSiteCtrl.text.trim().isNotEmpty) payload['website'] = _firmSiteCtrl.text.trim();
//       }

//       final res = await auth.register(payload);

//       if (!mounted) return;

//       if (res['success'] == true) {
//         final dest = auth.isAdmin ? '/admin' : '/main';
//         context.go('$dest?tab=competitions');
//       } else {
//         setState(() => _error = res['message'] ?? 'Registration failed. Please try again.');
//       }
//     } catch (e) {
//       setState(() => _error = 'Network error: ${e.toString()}');
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _handleGoogleOAuth() async {
//     setState(() {
//       _oauthLoading = true;
//       _error = null;
//     });
//     try {
//       final api = ApiService();
//       final res = await api.getGoogleAuthUrl();
//       final url = res['data']?['authUrl']?.toString() ?? res['authUrl']?.toString();
//       if (url == null || url.isEmpty) throw Exception('Failed to get OAuth URL');
//       final uri = Uri.parse(url);
//       if (!await canLaunchUrl(uri)) throw Exception('Could not launch OAuth URL');
//       await launchUrl(uri, mode: LaunchMode.externalApplication);
//     } catch (e) {
//       setState(() => _error = 'Failed to initiate Google login: $e');
//     } finally {
//       if (mounted) setState(() => _oauthLoading = false);
//     }
//   }

//   String? _validateEmail(String? v) {
//     final s = (v ?? '').trim();
//     if (s.isEmpty) return 'Email is required';
//     final re = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$');
//     if (!re.hasMatch(s)) return 'Enter a valid email';
//     return null;
//   }

//   String? _validatePassword(String? v) {
//     if (v == null || v.isEmpty) return 'Password is required';
//     if (v.length < 6) return 'At least 6 characters';
//     return null;
//   }

//   String? _validateUrlOptional(String? v) {
//     final s = (v ?? '').trim();
//     if (s.isEmpty) return null;
//     if (!s.startsWith('http://') && !s.startsWith('https://')) {
//       return 'Use http(s)://…';
//     }
//     return null;
//   }

//   String? _validateIntOptional(String? v) {
//     final s = (v ?? '').trim();
//     if (s.isEmpty) return null;
//     if (int.tryParse(s) == null) return 'Enter a number';
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;
//     final canPop = GoRouter.of(context).canPop() || Navigator.of(context).canPop();
//     final showOAuth = !_isAdmin; // change to `_isStudent` if students only

//     return PopScope(
//       canPop: false,
//       onPopInvoked: (didPop) {
//         if (!didPop) _smartBack();
//       },
//       child: GestureDetector(
//         behavior: HitTestBehavior.opaque,
//         onTap: () => FocusScope.of(context).unfocus(),
//         child: Scaffold(
//           appBar: AppBar(
//             automaticallyImplyLeading: canPop,
//             leading: canPop
//                 ? IconButton(
//                     icon: const Icon(Icons.arrow_back),
//                     onPressed: _busy ? null : _smartBack,
//                   )
//                 : null,
//             title: const Text('Register'),
//             actions: [
//               Padding(
//                 padding: const EdgeInsets.only(right: 12),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: theme.colorScheme.surface,
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(_roleIcon(_role), size: 16, color: theme.colorScheme.primary),
//                       const SizedBox(width: 6),
//                       Text(_role.toUpperCase(), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
//                     ],
//                   ),
//                 ),
//               )
//             ],
//           ),
//           body: SafeArea(
//             child: ScrollConfiguration(
//               behavior: const MaterialScrollBehavior().copyWith(
//                 scrollbars: false, // Hides scrollbar on web/desktop; mobile never shows anyway
//               ),
//               child: SingleChildScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 padding: const EdgeInsets.all(24),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       // Header
//                       Row(
//                         children: [
//                           Container(
//                             width: 48,
//                             height: 48,
//                             decoration: BoxDecoration(
//                               color: theme.colorScheme.primary.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Icon(Icons.person_add, color: theme.colorScheme.primary),
//                           ),
//                           const SizedBox(width: 16),
//                           Expanded(
//                             child: Text('Create your account', style: theme.textTheme.headlineMedium),
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 24),

//                       // Name (CustomTextField without unsupported params)
//                       CustomTextField(
//                         controller: _nameCtrl,
//                         label: 'Full Name',
//                         prefixIcon: Icons.person_outline,
//                         validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
//                       ),
//                       const SizedBox(height: 16),

//                       // Email (native TextFormField to use focus & actions)
//                       TextFormField(
//                         controller: _emailCtrl,
//                         focusNode: _emailFocus,
//                         keyboardType: TextInputType.emailAddress,
//                         textInputAction: TextInputAction.next,
//                         autofillHints: const [AutofillHints.email],
//                         onFieldSubmitted: (_) => _passFocus.requestFocus(),
//                         decoration: const InputDecoration(
//                           labelText: 'Email',
//                           prefixIcon: Icon(Icons.email_outlined),
//                         ),
//                         validator: _validateEmail,
//                       ),
//                       const SizedBox(height: 16),

//                       // Password (native)
//                       TextFormField(
//                         controller: _passCtrl,
//                         focusNode: _passFocus,
//                         obscureText: _obscure,
//                         textInputAction: TextInputAction.next,
//                         onFieldSubmitted: (_) => _extra1Focus.requestFocus(),
//                         decoration: InputDecoration(
//                           labelText: 'Password',
//                           prefixIcon: const Icon(Icons.lock_outline),
//                           suffixIcon: IconButton(
//                             onPressed: () => setState(() => _obscure = !_obscure),
//                             icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
//                             tooltip: _obscure ? 'Show' : 'Hide',
//                           ),
//                         ),
//                         validator: _validatePassword,
//                       ),

//                       // ---- Role-specific fields ----
//                       if (_isStudent) ...[
//                         const SizedBox(height: 16),
//                         CustomTextField(
//                           controller: _collegeCtrl,
//                           label: 'College (Optional)',
//                           prefixIcon: Icons.school_outlined,
//                         ),
//                         const SizedBox(height: 16),
//                         CustomTextField(
//                           controller: _branchCtrl,
//                           label: 'Branch (Optional)',
//                           prefixIcon: Icons.class_outlined,
//                         ),
//                         const SizedBox(height: 16),
//                         TextFormField(
//                           controller: _yearCtrl,
//                           focusNode: _extra1Focus,
//                           keyboardType: TextInputType.number,
//                           textInputAction: TextInputAction.done,
//                           decoration: const InputDecoration(
//                             labelText: 'Year (Optional)',
//                             prefixIcon: Icon(Icons.calendar_today_outlined),
//                           ),
//                           validator: _validateIntOptional,
//                         ),
//                       ],

//                       if (_isHiring) ...[
//                         const SizedBox(height: 16),
//                         CustomTextField(
//                           controller: _companyNameCtrl,
//                           label: 'Company name',
//                           prefixIcon: Icons.business_outlined,
//                         ),
//                         const SizedBox(height: 16),
//                         TextFormField(
//                           controller: _companySiteCtrl,
//                           focusNode: _extra1Focus,
//                           keyboardType: TextInputType.url,
//                           textInputAction: TextInputAction.next,
//                           onFieldSubmitted: (_) => _extra2Focus.requestFocus(),
//                           decoration: const InputDecoration(
//                             labelText: 'Company website',
//                             prefixIcon: Icon(Icons.link_outlined),
//                           ),
//                           validator: _validateUrlOptional,
//                         ),
//                         const SizedBox(height: 16),
//                         TextFormField(
//                           controller: _teamSizeCtrl,
//                           focusNode: _extra2Focus,
//                           keyboardType: TextInputType.number,
//                           textInputAction: TextInputAction.done,
//                           decoration: const InputDecoration(
//                             labelText: 'Team size',
//                             prefixIcon: Icon(Icons.people_alt_outlined),
//                           ),
//                           validator: _validateIntOptional,
//                         ),
//                       ],

//                       if (_isInvestor) ...[
//                         const SizedBox(height: 16),
//                         CustomTextField(
//                           controller: _firmNameCtrl,
//                           label: 'Firm / Angel name',
//                           prefixIcon: Icons.business_outlined,
//                         ),
//                         const SizedBox(height: 16),
//                         CustomTextField(
//                           controller: _stageCtrl,
//                           label: 'Investment stage (seed/series A)',
//                           prefixIcon: Icons.rocket_launch_outlined,
//                         ),
//                         const SizedBox(height: 16),
//                         TextFormField(
//                           controller: _firmSiteCtrl,
//                           focusNode: _extra1Focus,
//                           keyboardType: TextInputType.url,
//                           textInputAction: TextInputAction.done,
//                           decoration: const InputDecoration(
//                             labelText: 'Website / portfolio',
//                             prefixIcon: Icon(Icons.link_outlined),
//                           ),
//                           validator: _validateUrlOptional,
//                         ),
//                       ],

//                       const SizedBox(height: 16),

//                       // Terms + Privacy
//                       Row(
//                         children: [
//                           Checkbox(
//                             value: _agree,
//                             onChanged: _busy ? null : (v) => setState(() => _agree = v ?? false),
//                           ),
//                           Expanded(
//                             child: Wrap(
//                               crossAxisAlignment: WrapCrossAlignment.center,
//                               children: [
//                                 const Text('I agree to the '),
//                                 InkWell(
//                                   onTap: _busy ? null : () => context.push('/terms'),
//                                   child: Text('Terms', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
//                                 ),
//                                 const Text(' & '),
//                                 InkWell(
//                                   onTap: _busy ? null : () => context.push('/privacy'),
//                                   child: Text('Privacy Policy', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
//                                 ),
//                                 const Text('.'),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),

//                       // Error
//                       if (_error != null) ...[
//                         const SizedBox(height: 8),
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: isDark ? Colors.red.shade900 : Colors.red.shade50,
//                             border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade200),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Text(
//                             _error!,
//                             style: TextStyle(
//                               color: isDark ? Colors.red.shade200 : Colors.red.shade700,
//                               fontSize: 14,
//                             ),
//                           ),
//                         ),
//                       ],

//                       const SizedBox(height: 16),

//                       // Submit
//                       LoadingButton(
//                         isLoading: _isLoading,
//                         onPressed: _busy ? () {} : _handleRegister,
//                         child: const Text('Register'),
//                       ),

//                       const SizedBox(height: 12),

//                       // Login link
//                       Center(
//                         child: TextButton(
//                           onPressed: _busy ? null : () => context.push('/login', extra: {'role': _role}),
//                           child: RichText(
//                             text: TextSpan(
//                               style: theme.textTheme.bodyMedium,
//                               children: [
//                                 const TextSpan(text: 'Already have an account? '),
//                                 TextSpan(
//                                   text: 'Login',
//                                   style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),

//                       // OAuth (hide for admin)
//                       if (showOAuth) ...[
//                         const SizedBox(height: 20),
//                         Row(
//                           children: [
//                             Expanded(child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 12),
//                               child: Text('OR', style: theme.textTheme.bodySmall),
//                             ),
//                             Expanded(child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
//                           ],
//                         ),
//                         const SizedBox(height: 16),
//                         OutlinedButton.icon(
//                           onPressed: _oauthLoading ? null : _handleGoogleOAuth,
//                           icon: const Icon(Icons.g_mobiledata, size: 24),
//                           label: Text(_oauthLoading ? 'Opening Google...' : 'Continue with Google'),
//                           style: OutlinedButton.styleFrom(
//                             padding: const EdgeInsets.symmetric(vertical: 16),
//                             side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../widgets/custom_widgets.dart'; // LoadingButton, CustomTextField

class RegisterScreen extends StatefulWidget {
  final String? role; // 'student' | 'hiring' | 'investor' | 'admin'

  const RegisterScreen({super.key, this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Common
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Student
  final _collegeCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  // Hiring team
  final _companyNameCtrl = TextEditingController();
  final _companySiteCtrl = TextEditingController();
  final _teamSizeCtrl = TextEditingController();

  // Investor
  final _firmNameCtrl = TextEditingController();
  final _stageCtrl = TextEditingController();
  final _firmSiteCtrl = TextEditingController();

  // Focus chain
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _extra1Focus = FocusNode();
  final _extra2Focus = FocusNode();

  bool _isLoading = false;
  bool _oauthLoading = false;
  bool _obscure = true;
  bool _agree = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();

    _collegeCtrl.dispose();
    _branchCtrl.dispose();
    _yearCtrl.dispose();

    _companyNameCtrl.dispose();
    _companySiteCtrl.dispose();
    _teamSizeCtrl.dispose();

    _firmNameCtrl.dispose();
    _stageCtrl.dispose();
    _firmSiteCtrl.dispose();

    _emailFocus.dispose();
    _passFocus.dispose();
    _extra1Focus.dispose();
    _extra2Focus.dispose();
    super.dispose();
  }

  String get _role => (widget.role ?? 'student').toLowerCase();
  bool get _isStudent => _role == 'student';
  bool get _isHiring => _role == 'hiring';
  bool get _isInvestor => _role == 'investor';
  bool get _isAdmin => _role == 'admin';
  bool get _busy => _isLoading || _oauthLoading;

  IconData _roleIcon(String r) {
    switch (r) {
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

  void _smartBack() {
    final r = GoRouter.of(context);
    if (r.canPop()) {
      r.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (!_agree) {
      setState(() => _error = 'Please agree to the Terms & Privacy.');
      return;
    }

    // Admin is invite-only (guard)
    if (_isAdmin) {
      setState(() => _error = 'Admin accounts are invite-only. Please use an admin invite link.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'role': _role,
        // match react: flags for agreements
        'agree_tnc': true,
        'agree_privacy': true,
      };

      if (_isStudent) {
        if (_collegeCtrl.text.trim().isNotEmpty) payload['college'] = _collegeCtrl.text.trim();
        if (_branchCtrl.text.trim().isNotEmpty) payload['branch'] = _branchCtrl.text.trim();
        final y = int.tryParse(_yearCtrl.text.trim());
        if (y != null) payload['year'] = y;
      } else if (_isHiring) {
        if (_companyNameCtrl.text.trim().isNotEmpty) payload['company_name'] = _companyNameCtrl.text.trim();
        if (_companySiteCtrl.text.trim().isNotEmpty) payload['company_website'] = _companySiteCtrl.text.trim();
        final ts = int.tryParse(_teamSizeCtrl.text.trim());
        if (ts != null) payload['team_size'] = ts;
      } else if (_isInvestor) {
        if (_firmNameCtrl.text.trim().isNotEmpty) payload['firm_name'] = _firmNameCtrl.text.trim();
        if (_stageCtrl.text.trim().isNotEmpty) payload['investment_stage'] = _stageCtrl.text.trim();
        if (_firmSiteCtrl.text.trim().isNotEmpty) payload['website'] = _firmSiteCtrl.text.trim();
      }

      final res = await auth.register(payload);

      if (!mounted) return;

      if (res['success'] == true) {
        // Go to the "check your email" notice screen (like React)
        final email = (_emailCtrl.text.trim());
        context.go('/verify-email-sent?email=${Uri.encodeComponent(email)}');
      } else {
        setState(() => _error = res['message'] ?? 'Registration failed. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleOAuth() async {
    setState(() {
      _oauthLoading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final res = await api.getGoogleAuthUrl();
      final url = res['data']?['authUrl']?.toString() ?? res['authUrl']?.toString();
      if (url == null || url.isEmpty) throw Exception('Failed to get OAuth URL');
      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) throw Exception('Could not launch OAuth URL');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _error = 'Failed to initiate Google login: $e');
    } finally {
      if (mounted) setState(() => _oauthLoading = false);
    }
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!re.hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'At least 6 characters';
    return null;
  }

  String? _validateUrlOptional(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      return 'Use http(s)://…';
    }
    return null;
  }

  String? _validateIntOptional(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (int.tryParse(s) == null) return 'Enter a number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPop = GoRouter.of(context).canPop() || Navigator.of(context).canPop();
    final showOAuth = !_isAdmin;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _smartBack();
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
            title: const Text('Register'),
            actions: [
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
                      Icon(_roleIcon(_role), size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(_role.toUpperCase(), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              )
            ],
          ),
          body: SafeArea(
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.person_add, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text('Create your account', style: theme.textTheme.headlineMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      CustomTextField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        prefixIcon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),

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
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passCtrl,
                        focusNode: _passFocus,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _extra1Focus.requestFocus(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            tooltip: _obscure ? 'Show' : 'Hide',
                          ),
                        ),
                        validator: _validatePassword,
                      ),

                      if (_isStudent) ...[
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _collegeCtrl,
                          label: 'College (Optional)',
                          prefixIcon: Icons.school_outlined,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _branchCtrl,
                          label: 'Branch (Optional)',
                          prefixIcon: Icons.class_outlined,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _yearCtrl,
                          focusNode: _extra1Focus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Year (Optional)',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          validator: _validateIntOptional,
                        ),
                      ],

                      if (_isHiring) ...[
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _companyNameCtrl,
                          label: 'Company name',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _companySiteCtrl,
                          focusNode: _extra1Focus,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _extra2Focus.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Company website',
                            prefixIcon: Icon(Icons.link_outlined),
                          ),
                          validator: _validateUrlOptional,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _teamSizeCtrl,
                          focusNode: _extra2Focus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Team size',
                            prefixIcon: Icon(Icons.people_alt_outlined),
                          ),
                          validator: _validateIntOptional,
                        ),
                      ],

                      if (_isInvestor) ...[
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _firmNameCtrl,
                          label: 'Firm / Angel name',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _stageCtrl,
                          label: 'Investment stage (seed/series A)',
                          prefixIcon: Icons.rocket_launch_outlined,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _firmSiteCtrl,
                          focusNode: _extra1Focus,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Website / portfolio',
                            prefixIcon: Icon(Icons.link_outlined),
                          ),
                          validator: _validateUrlOptional,
                        ),
                      ],

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Checkbox(
                            value: _agree,
                            onChanged: _busy ? null : (v) => setState(() => _agree = v ?? false),
                          ),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('I agree to the '),
                                InkWell(
                                  onTap: _busy ? null : () => context.push('/terms'),
                                  child: Text('Terms', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                                ),
                                const Text(' & '),
                                InkWell(
                                  onTap: _busy ? null : () => context.push('/privacy'),
                                  child: Text('Privacy Policy', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                                ),
                                const Text('.'),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.red.shade900 : Colors.red.shade50,
                            border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: isDark ? Colors.red.shade200 : Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      LoadingButton(
                        isLoading: _isLoading,
                        onPressed: _busy ? () {} : _handleRegister,
                        child: const Text('Register'),
                      ),

                      const SizedBox(height: 12),

                      Center(
                        child: TextButton(
                          onPressed: _busy ? null : () => context.push('/login', extra: {'role': _role}),
                          child: RichText(
                            text: TextSpan(
                              style: theme.textTheme.bodyMedium,
                              children: [
                                const TextSpan(text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Login',
                                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (showOAuth) ...[
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
                          onPressed: _oauthLoading ? null : _handleGoogleOAuth,
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
    );
  }
}
