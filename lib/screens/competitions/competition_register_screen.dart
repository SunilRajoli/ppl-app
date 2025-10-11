// lib/screens/competitions/competition_register_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';

/// Competition Register Screen (Flutter)
/// Styled to match CompetitionSubmitScreen inputs (no inner borders)

class CompetitionRegisterScreen extends StatefulWidget {
  final String? competitionId;

  const CompetitionRegisterScreen({super.key, this.competitionId});

  @override
  State<CompetitionRegisterScreen> createState() => _CompetitionRegisterScreenState();
}

class _CompetitionRegisterScreenState extends State<CompetitionRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  // ---------------------- loading & server state ----------------------
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _competition;

  // ----------------------------- auth/user ----------------------------
  Map<String, dynamic>? _me;

  // --------------------------- registration ---------------------------
  String _registrationType = 'individual'; // 'individual' | 'team'

  // Applicant (leader) fields — mirrors React "applicant"
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _gender = 'prefer_not_to_say';
  final _orgCtrl = TextEditingController();
  String _eduType = 'undergraduate';
  final _workExpCtrl = TextEditingController(); // only for graduate

  // Team
  final _teamNameCtrl = TextEditingController();
  final _abstractCtrl = TextEditingController();

  // Member draft (a single row to add)
  final _mName = TextEditingController();
  final _mEmail = TextEditingController();
  final _mPhone = TextEditingController();
  String _mGender = 'prefer_not_to_say';
  final _mOrg = TextEditingController();
  String _mEdu = 'undergraduate';
  final _mWorkYears = TextEditingController();

  // Members list
  final List<_Member> _members = <_Member>[];

  // Agreements
  bool _agreeTnC = false;
  bool _agreePrivacy = false;

  // UI fx
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Pricing (display only — React has it for reference)
  static const int _FEE_UNDERGRAD = 500;
  static const int _FEE_GRADUATE = 1000;

  int _feeFor(String eduType) => eduType == 'graduate' ? _FEE_GRADUATE : _FEE_UNDERGRAD;

  String get _idFromRouterOrParam {
    final passed = widget.competitionId;
    if (passed != null && passed.isNotEmpty) return passed;
    final id = GoRouterState.of(context).pathParameters['id'];
    return id ?? '';
  }

  int _asInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  int get _maxTeamSize => _asInt(_competition?['max_team_size'], 1);
  int get _seatsRemaining => _asInt(_competition?['seats_remaining'], 0);

  // Fees (display only)
  int get _leaderFee => _feeFor(_eduType);
  int get _membersFee => _members.fold(0, (sum, m) => sum + _feeFor(m.eduType));
  int get _totalFee =>
      _registrationType == 'individual' ? _leaderFee : (_leaderFee + _membersFee);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureAuthAndLoad();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _orgCtrl.dispose();
    _workExpCtrl.dispose();

    _teamNameCtrl.dispose();
    _abstractCtrl.dispose();

    _mName.dispose();
    _mEmail.dispose();
    _mPhone.dispose();
    _mOrg.dispose();
    _mWorkYears.dispose();

    _anim.dispose();
    super.dispose();
  }

  Future<void> _ensureAuthAndLoad() async {
    if (!_loading && _competition != null) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    // seed known info from provider
    final user = auth.user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _emailCtrl.text = user.email; // read-only in UI (like React)
      _phoneCtrl.text = (user.toJson()['phone'] ?? '').toString();
      _orgCtrl.text = (user.toJson()['org'] ?? user.toJson()['company_name'] ?? '').toString();
      _gender = (user.toJson()['gender'] ?? 'prefer_not_to_say').toString();
      _eduType = (user.toJson()['edu_type'] ?? 'undergraduate').toString();
      final wy = user.toJson()['work_experience_years'];
      _workExpCtrl.text = wy == null ? '' : wy.toString();
    }

    final id = _idFromRouterOrParam;
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing competition ID';
      });
      return;
    }

    await Future.wait([
      _loadMe(),
      _loadCompetition(id),
    ]);
  }

  Future<void> _loadMe() async {
    try {
      final res = await _api.getProfile();
      final data = res?['data'] ?? res;
      final u = (data?['user'] ?? data) as Map<String, dynamic>?;

      if (u != null) {
        _me = u;
        // hydrate applicant with latest server values
        setState(() {
          _nameCtrl.text = (u['name'] ?? _nameCtrl.text).toString();
          _emailCtrl.text = (u['email'] ?? _emailCtrl.text).toString();
          _phoneCtrl.text = (u['phone'] ?? _phoneCtrl.text).toString();
          _orgCtrl.text = (u['org'] ?? u['company_name'] ?? _orgCtrl.text).toString();
          _gender = (u['gender'] ?? _gender).toString();
          _eduType = (u['edu_type'] ?? _eduType).toString();
          final wy = u['work_experience_years'];
          _workExpCtrl.text = wy == null ? _workExpCtrl.text : wy.toString();
        });
      }
    } catch (_) {
      // ignore silently (React swallows errors here)
    }
  }

  Future<void> _loadCompetition(String id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getCompetition(id);
      final data = res is Map ? (res['data'] ?? res) : res;
      final comp = (data is Map) ? (data['competition'] ?? data) : null;

      if (comp is Map) {
        setState(() {
          _competition = Map<String, dynamic>.from(comp);
          _error = null;
        });
        _anim.forward();
      } else {
        setState(() {
          _competition = null;
          _error = 'Competition not found';
        });
      }
    } catch (e) {
      setState(() {
        _competition = null;
        _error = e.toString();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  bool _emailFormatOk(String email) =>
      RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$', caseSensitive: false)
          .hasMatch(email.trim());

  String _normalizeEmail(String email) => email.trim().toLowerCase();
  String _normalizePhone(String p) => p.trim();

  String? _validatePerson({
    required String name,
    required String email,
    required String phone,
    required String org,
    required String eduType,
    required String workYears,
    required bool isLeader,
  }) {
    final e = _normalizeEmail(email);
    final n = name.trim();
    final ph = _normalizePhone(phone);

    if (n.isEmpty || n.length < 2) return 'Please enter full name';
    if (!_emailFormatOk(e)) return 'Please enter a valid email';
    if (ph.isEmpty || !RegExp(r'^\+?\d[\d\s\-()]{6,}$').hasMatch(ph)) {
      return 'Please enter a valid mobile number';
    }
    if (org.trim().length < 2) return 'Please enter organization/institution';
    if (!['undergraduate', 'graduate', 'other'].contains(eduType)) {
      return 'Please select a valid Type';
    }
    if (eduType == 'graduate') {
      final years = int.tryParse(workYears.isEmpty ? '0' : workYears);
      if (years == null || years < 0 || years > 60) {
        return 'Please enter valid work experience (0–60 years)';
      }
    }
    if (isLeader && (!this._agreeTnC || !this._agreePrivacy)) {
      return 'You must agree to the Terms & Conditions and Privacy Policy';
    }
    return null;
  }

  Future<bool> _checkUserExistsOrToast(String email) async {
    final normalized = _normalizeEmail(email);
    try {
      // Keep parity with React; if no endpoint exists, skip.
      return true;
    } catch (_) {
      _toast('Could not verify user. Please try again.');
      return false;
    }
  }

  void _addMember() async {
    final err = _validatePerson(
      name: _mName.text,
      email: _mEmail.text,
      phone: _mPhone.text,
      org: _mOrg.text,
      eduType: _mEdu,
      workYears: _mWorkYears.text,
      isLeader: false,
    );
    if (err != null) return _toast(err);

    // max size includes leader (you) + members
    if (1 + _members.length + 1 > _maxTeamSize) {
      return _toast('Maximum team size is $_maxTeamSize (including you).');
    }

    if (!await _checkUserExistsOrToast(_mEmail.text)) return;

    final existsAlready = _normalizeEmail(_emailCtrl.text) == _normalizeEmail(_mEmail.text) ||
        _members.any((m) => _normalizeEmail(m.email) == _normalizeEmail(_mEmail.text));
    if (existsAlready) return _toast('This email is already part of the team.');

    setState(() {
      _members.add(_Member(
        name: _mName.text.trim(),
        email: _normalizeEmail(_mEmail.text),
        phone: _normalizePhone(_mPhone.text),
        gender: _mGender,
        org: _mOrg.text.trim(),
        eduType: _mEdu,
        workYears: _mEdu == 'graduate' ? (_mWorkYears.text.trim().isEmpty ? '0' : _mWorkYears.text.trim()) : '0',
      ));
      _mName.clear();
      _mEmail.clear();
      _mPhone.clear();
      _mGender = 'prefer_not_to_say';
      _mOrg.clear();
      _mEdu = 'undergraduate';
      _mWorkYears.clear();
    });
    _toast('Member added');
  }

  void _removeMemberAt(int index) {
    setState(() => _members.removeAt(index));
    _toast('Member removed');
  }

  bool get _canSubmit {
    if (_competition == null) return false;
    if (_seatsRemaining <= 0) return false;
    if (!_agreeTnC || !_agreePrivacy) return false;
    if (_registrationType == 'team' && _teamNameCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _handleSubmit() async {
    if (_competition == null) return;
    final id = _idFromRouterOrParam;

    // Validate leader
    final leaderErr = _validatePerson(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      org: _orgCtrl.text,
      eduType: _eduType,
      workYears: _workExpCtrl.text,
      isLeader: true,
    );
    if (leaderErr != null) return _toast(leaderErr);

    // Leader must exist
    if (!await _checkUserExistsOrToast(_emailCtrl.text)) return;

    // Validate members if any
    if (_registrationType == 'team' && _members.isNotEmpty) {
      for (final m in _members) {
        final err = _validatePerson(
          name: m.name,
          email: m.email,
          phone: m.phone,
          org: m.org,
          eduType: m.eduType,
          workYears: m.workYears,
          isLeader: false,
        );
        if (err != null) return _toast(err);
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // --- React updates profile before registering (best-effort) ---
      try {
        await _api.updateProfile({
          'name': _nameCtrl.text.trim(),
          'phone': _normalizePhone(_phoneCtrl.text),
          'org': _orgCtrl.text.trim(),
          'gender': _gender,
          'edu_type': _eduType,
          'work_experience_years': _eduType == 'graduate'
              ? int.tryParse(_workExpCtrl.text.trim().isEmpty ? '0' : _workExpCtrl.text.trim()) ?? 0
              : 0,
          'agree_tnc': _agreeTnC,
          'agree_privacy': _agreePrivacy,
        });
      } catch (_) {
        // ignore failure like React does
      }

      // (Payment flow intentionally disabled for parity with React)

      // 2) Submit competition registration (without payment)
      final payload = <String, dynamic>{
        'type': _registrationType,
        if (_registrationType == 'team') 'team_name': _teamNameCtrl.text.trim(),
        if (_abstractCtrl.text.trim().isNotEmpty) 'abstract': _abstractCtrl.text.trim(),
        'applicant': {
          'name': _nameCtrl.text.trim(),
          'email': _normalizeEmail(_emailCtrl.text),
          'phone': _normalizePhone(_phoneCtrl.text),
          'gender': _gender,
          'org': _orgCtrl.text.trim(),
          'edu_type': _eduType,
          'work_experience_years': _eduType == 'graduate'
              ? (int.tryParse(_workExpCtrl.text.trim().isEmpty ? '0' : _workExpCtrl.text.trim()) ?? 0)
              : 0,
          'agree_tnc': _agreeTnC,
          'agree_privacy': _agreePrivacy,
        },
        'members': _registrationType == 'team'
            ? _members
                .map((m) => {
                      'name': m.name,
                      'email': _normalizeEmail(m.email),
                      'phone': _normalizePhone(m.phone),
                      'gender': m.gender,
                      'org': m.org,
                      'edu_type': m.eduType,
                      'work_experience_years':
                          m.eduType == 'graduate' ? (int.tryParse(m.workYears) ?? 0) : 0,
                    })
                .toList()
            : <Map<String, dynamic>>[],
      };

      final res = await _api.registerForCompetition(id, payload);
      final ok = (res is Map) ? (res['success'] == true) : false;

      if (ok) {
        if (!mounted) return;
        _toast('Registration submitted successfully!');
        context.pop(true);
      } else {
        final msg = (res is Map ? res['message']?.toString() : null) ?? 'Registration failed';
        setState(() => _error = msg);
        _toast(msg);
      }
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      _toast(msg);
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline.withOpacity(.25);

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registration Form'),
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Close',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
                )
              : (_competition == null
                  ? _ErrorView(
                      error: _error ?? 'Competition not found',
                      onRetry: () => _loadCompetition(_idFromRouterOrParam),
                    )
                  : FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: RefreshIndicator(
                          onRefresh: () => _loadCompetition(_idFromRouterOrParam),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: [
                              // Optional banner (safe network image)
                              if ((_competition?['banner_url'] as String?)?.isNotEmpty == true) ...[
                                NetImageSafe(url: _competition?['banner_url'] as String?),
                                const SizedBox(height: 12),
                              ],

                              // Header
                              _HeaderCard(
                                title: 'Registration Form',
                                subtitle: (_competition?['title'] ?? '').toString(),
                              ),

                              const SizedBox(height: 12),

                              // Main form container
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Registration Type
                                    Text('Registration Type',
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => setState(() => _registrationType = 'individual'),
                                            icon: const Icon(Icons.person_outline),
                                            label: const Text('Individual'),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: _registrationType == 'individual'
                                                  ? theme.colorScheme.surfaceVariant.withOpacity(.35)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => setState(() => _registrationType = 'team'),
                                            icon: const Icon(Icons.groups_outlined),
                                            label: const Text('Team'),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: _registrationType == 'team'
                                                  ? theme.colorScheme.surfaceVariant.withOpacity(.35)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // Team name
                                    if (_registrationType == 'team') ...[
                                      Text('Team Name', style: theme.textTheme.titleSmall),
                                      const SizedBox(height: 6),
                                      _IconField(
                                        controller: _teamNameCtrl,
                                        hint: 'Enter your team name',
                                        icon: Icons.badge_outlined,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Team size (including you): up to ${_maxTeamSize}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // Leader (Your details)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Your Details',
                                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                        _FeePill(eduType: _eduType),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Name
                                    _LabeledRow(
                                      label: 'Full Name',
                                      child: _IconField(
                                        controller: _nameCtrl,
                                        hint: 'Your name',
                                        icon: Icons.person_outline,
                                        textInputAction: TextInputAction.next,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Email + Phone
                                    LayoutBuilder(builder: (ctx, c) {
                                      return (c.maxWidth >= 640)
                                          ? Row(
                                              children: [
                                                Expanded(
                                                  child: _LabeledRow(
                                                    label: 'Email',
                                                    child: _IconField(
                                                      controller: _emailCtrl,
                                                      hint: 'you@example.com',
                                                      icon: Icons.mail_outline,
                                                      readOnly: true, // React marks it readOnly
                                                      keyboardType: TextInputType.emailAddress,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: _LabeledRow(
                                                    label: 'Mobile Number',
                                                    child: _IconField(
                                                      controller: _phoneCtrl,
                                                      hint: '+91 90000 00000',
                                                      icon: Icons.phone_outlined,
                                                      keyboardType: TextInputType.phone,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              children: [
                                                _LabeledRow(
                                                  label: 'Email',
                                                  child: _IconField(
                                                    controller: _emailCtrl,
                                                    hint: 'you@example.com',
                                                    icon: Icons.mail_outline,
                                                    readOnly: true,
                                                    keyboardType: TextInputType.emailAddress,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                _LabeledRow(
                                                  label: 'Mobile Number',
                                                  child: _IconField(
                                                    controller: _phoneCtrl,
                                                    hint: '+91 90000 00000',
                                                    icon: Icons.phone_outlined,
                                                    keyboardType: TextInputType.phone,
                                                  ),
                                                ),
                                              ],
                                            );
                                    }),
                                    const SizedBox(height: 10),

                                    // Gender + Org
                                    LayoutBuilder(builder: (ctx, c) {
                                      final left = _DropdownRow(
                                        label: 'Gender',
                                        value: _gender,
                                        items: const [
                                          DropdownMenuItem(value: 'male', child: Text('Male')),
                                          DropdownMenuItem(value: 'female', child: Text('Female')),
                                          DropdownMenuItem(value: 'non_binary', child: Text('Non-binary')),
                                          DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
                                        ],
                                        onChanged: (v) => setState(() => _gender = v ?? 'prefer_not_to_say'),
                                      );
                                      final right = _LabeledRow(
                                        label: 'Organization / Institution',
                                        child: _IconField(
                                          controller: _orgCtrl,
                                          hint: 'Your college or company',
                                          icon: Icons.apartment_outlined,
                                        ),
                                      );
                                      return (c.maxWidth >= 640)
                                          ? Row(children: [
                                              Expanded(child: left),
                                              const SizedBox(width: 10),
                                              Expanded(child: right),
                                            ])
                                          : Column(children: [
                                              left,
                                              const SizedBox(height: 10),
                                              right,
                                            ]);
                                    }),
                                    const SizedBox(height: 10),

                                    // Type + Work Exp (conditional)
                                    LayoutBuilder(builder: (ctx, c) {
                                      final left = _LabeledRow(
                                        label: 'Type',
                                        child: _IconDropdown(
                                          icon: Icons.school_outlined,
                                          value: _eduType,
                                          items: const [
                                            DropdownMenuItem(value: 'undergraduate', child: Text('Undergraduate')),
                                            DropdownMenuItem(value: 'graduate', child: Text('Graduate')),
                                            DropdownMenuItem(value: 'other', child: Text('Other')),
                                          ],
                                          onChanged: (v) => setState(() => _eduType = v ?? 'undergraduate'),
                                        ),
                                      );

                                      final right = (_eduType == 'graduate')
                                          ? _LabeledRow(
                                              label: 'Work Experience (years)',
                                              child: _IconField(
                                                controller: _workExpCtrl,
                                                hint: 'e.g., 2',
                                                icon: Icons.work_outline,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              ),
                                            )
                                          : const SizedBox.shrink();

                                      return (c.maxWidth >= 640)
                                          ? Row(children: [
                                              Expanded(child: left),
                                              const SizedBox(width: 10),
                                              Expanded(child: right),
                                            ])
                                          : Column(children: [
                                              left,
                                              if (_eduType == 'graduate') ...[
                                                const SizedBox(height: 10),
                                                right,
                                              ],
                                            ]);
                                    }),

                                    const SizedBox(height: 20),

                                    // Team Members
                                    if (_registrationType == 'team') ...[
                                      Text('Team Members', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 10),

                                      // Member Draft Card
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: border),
                                          color: theme.colorScheme.surfaceVariant.withOpacity(.10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Add Member', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                                                _FeePill(eduType: _mEdu),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            _LabeledRow(
                                              label: 'Full Name',
                                              child: _IconField(
                                                controller: _mName,
                                                hint: 'Member name',
                                                icon: Icons.person_outline,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            LayoutBuilder(builder: (ctx, c) {
                                              return (c.maxWidth >= 640)
                                                  ? Row(children: [
                                                      Expanded(
                                                        child: _LabeledRow(
                                                          label: 'Email',
                                                          child: _IconField(
                                                            controller: _mEmail,
                                                            hint: 'member@example.com',
                                                            icon: Icons.mail_outline,
                                                            keyboardType: TextInputType.emailAddress,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: _LabeledRow(
                                                          label: 'Mobile Number',
                                                          child: _IconField(
                                                            controller: _mPhone,
                                                            hint: '+91 9xxxx xxxxx',
                                                            icon: Icons.phone_outlined,
                                                            keyboardType: TextInputType.phone,
                                                          ),
                                                        ),
                                                      ),
                                                    ])
                                                  : Column(children: [
                                                      _LabeledRow(
                                                        label: 'Email',
                                                        child: _IconField(
                                                          controller: _mEmail,
                                                          hint: 'member@example.com',
                                                          icon: Icons.mail_outline,
                                                          keyboardType: TextInputType.emailAddress,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 10),
                                                      _LabeledRow(
                                                        label: 'Mobile Number',
                                                        child: _IconField(
                                                          controller: _mPhone,
                                                          hint: '+91 9xxxx xxxxx',
                                                          icon: Icons.phone_outlined,
                                                          keyboardType: TextInputType.phone,
                                                        ),
                                                      ),
                                                    ]);
                                            }),
                                            const SizedBox(height: 10),
                                            LayoutBuilder(builder: (ctx, c) {
                                              final left = _DropdownRow(
                                                label: 'Gender',
                                                value: _mGender,
                                                items: const [
                                                  DropdownMenuItem(value: 'male', child: Text('Male')),
                                                  DropdownMenuItem(value: 'female', child: Text('Female')),
                                                  DropdownMenuItem(value: 'non_binary', child: Text('Non-binary')),
                                                  DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
                                                ],
                                                onChanged: (v) => setState(() => _mGender = v ?? 'prefer_not_to_say'),
                                              );
                                              final right = _LabeledRow(
                                                label: 'Organization / Institution',
                                                child: _IconField(
                                                  controller: _mOrg,
                                                  hint: 'College or company',
                                                  icon: Icons.apartment_outlined,
                                                ),
                                              );
                                              return (c.maxWidth >= 640)
                                                  ? Row(children: [
                                                      Expanded(child: left),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: right),
                                                    ])
                                                  : Column(children: [
                                                      left,
                                                      const SizedBox(height: 10),
                                                      right,
                                                    ]);
                                            }),
                                            const SizedBox(height: 10),
                                            LayoutBuilder(builder: (ctx, c) {
                                              final left = _LabeledRow(
                                                label: 'Type',
                                                child: _IconDropdown(
                                                  icon: Icons.school_outlined,
                                                  value: _mEdu,
                                                  items: const [
                                                    DropdownMenuItem(value: 'undergraduate', child: Text('Undergraduate')),
                                                    DropdownMenuItem(value: 'graduate', child: Text('Graduate')),
                                                    DropdownMenuItem(value: 'other', child: Text('Other')),
                                                  ],
                                                  onChanged: (v) => setState(() => _mEdu = v ?? 'undergraduate'),
                                                ),
                                              );

                                              final right = (_mEdu == 'graduate')
                                                  ? _LabeledRow(
                                                      label: 'Work Experience (years)',
                                                      child: _IconField(
                                                        controller: _mWorkYears,
                                                        hint: 'e.g., 1',
                                                        icon: Icons.work_outline,
                                                        keyboardType: TextInputType.number,
                                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      ),
                                                    )
                                                  : const SizedBox.shrink();

                                              return (c.maxWidth >= 640)
                                                  ? Row(children: [
                                                      Expanded(child: left),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: right),
                                                    ])
                                                  : Column(children: [
                                                      left,
                                                      if (_mEdu == 'graduate') ...[
                                                        const SizedBox(height: 10),
                                                        right,
                                                      ],
                                                    ]);
                                            }),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: OutlinedButton.icon(
                                                onPressed: _addMember,
                                                icon: const Icon(Icons.add),
                                                label: const Text('Add Member'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Members list
                                      if (_members.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text('Team Members (${_members.length})',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            )),
                                        const SizedBox(height: 6),
                                        LayoutBuilder(builder: (ctx, c) {
                                          final twoCol = c.maxWidth >= 840;
                                          final children = _members.asMap().entries.map((e) {
                                            final i = e.key;
                                            final m = e.value;
                                            return Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: border),
                                                color: theme.colorScheme.surfaceVariant.withOpacity(.10),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(m.name.isNotEmpty ? m.name : 'Member',
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: theme.textTheme.bodyLarge?.copyWith(
                                                              fontWeight: FontWeight.w600,
                                                            )),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _FeePill(eduType: m.eduType),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _kv(theme, 'Email', m.email),
                                                  _kv(theme, 'Phone', m.phone),
                                                  _kv(theme, 'Org', m.org),
                                                  _kv(
                                                    theme,
                                                    'Type',
                                                    m.eduType +
                                                        (m.eduType == 'graduate'
                                                            ? ' • ${int.tryParse(m.workYears) ?? 0} yrs exp'
                                                            : ''),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: TextButton.icon(
                                                      onPressed: () => _removeMemberAt(i),
                                                      icon: const Icon(Icons.delete_outline),
                                                      label: const Text('Remove'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList();

                                          if (twoCol) {
                                            // 2 columns
                                            return GridView.count(
                                              crossAxisCount: 2,
                                              childAspectRatio: 1.8,
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 10,
                                              children: children,
                                            );
                                          }
                                          return Column(
                                            children: [
                                              for (final w in children) ...[
                                                w,
                                                const SizedBox(height: 10),
                                              ]
                                            ],
                                          );
                                        }),
                                      ],
                                    ],

                                    const SizedBox(height: 16),

                                    // Project Abstract
                                    Text('Project Abstract', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                    Text('(Optional)',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        )),
                                    const SizedBox(height: 6),
                                    _MultilineField(
                                      controller: _abstractCtrl,
                                      hint: 'Describe your project idea, approach, or solution...',
                                      leading: Icons.description_outlined,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Fees & Payment (display only)
                              _FeesPreviewCard(
                                leaderEmail: _emailCtrl.text,
                                leaderEduType: _eduType,
                                leaderFee: _leaderFee,
                                members: _members,
                                feeFor: _feeFor,
                                total: _totalFee,
                              ),

                              const SizedBox(height: 12),

                              // Agreements (smaller text)
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: _agreeTnC,
                                      onChanged: (v) => setState(() => _agreeTnC = v ?? false),
                                      title: Text(
                                        'I agree to the Terms & Conditions',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(height: 4),
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: _agreePrivacy,
                                      onChanged: (v) => setState(() => _agreePrivacy = v ?? false),
                                      title: Text(
                                        'I agree to the Privacy Policy',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.withOpacity(.25)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade300),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: (_submitting || !_canSubmit) ? null : _handleSubmit,
                                  child: Text(_submitting ? 'Submitting Registration…' : 'Submit Registration'),
                                ),
                              ),

                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.center,
                                child: TextButton.icon(
                                  onPressed: _submitting ? null : () => context.pop(),
                                  icon: const Icon(Icons.chevron_left),
                                  label: const Text('Cancel'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
        ),
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text('$k: ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(child: Text(v, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/* ---------------------- Models & small UI blocks ---------------------- */

class _Member {
  final String name;
  final String email;
  final String phone;
  final String gender;
  final String org;
  final String eduType;
  final String workYears;
  _Member({
    required this.name,
    required this.email,
    required this.phone,
    required this.gender,
    required this.org,
    required this.eduType,
    required this.workYears,
  });
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline.withOpacity(.25);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: const Icon(Icons.groups, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

/// Matches submit screen: no inner border, just padded row with optional icon
class _IconField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final TextInputAction? textInputAction;
  const _IconField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface, // flat like submit screen
          borderRadius: BorderRadius.circular(12),
          // NO border here to avoid double outline
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textInputAction: textInputAction,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintMaxLines: 1,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Dropdown styled like submit inputs: no inner border, expands to width
class _IconDropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  const _IconDropdown({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface, // flat
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _LabeledRow(
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface, // flat
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _MultilineField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? leading;

  const _MultilineField({
    required this.controller,
    required this.hint,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // flat like submit screen
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            const SizedBox(height: 4),
            Icon(leading, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '',
              ).copyWith(hintText: hint),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeePill extends StatelessWidget {
  final String eduType;
  const _FeePill({required this.eduType});

  @override
  Widget build(BuildContext context) {
    final isGrad = eduType == 'graduate';
    final label = isGrad ? '₹1000 • Graduate' : '₹500 • Undergraduate';
    final borderCol = (isGrad ? Colors.pink : Colors.green).withOpacity(.4);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderCol),
          gradient: LinearGradient(
            colors: isGrad
                ? [Colors.pinkAccent, Colors.redAccent]
                : [Colors.green, Colors.lightGreen],
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _FeeRow {
  final String participant;
  final String type;
  final int fee;
  _FeeRow(this.participant, this.type, this.fee);
}

class _FeesPreviewCard extends StatelessWidget {
  final String leaderEmail;
  final String leaderEduType;
  final int leaderFee;
  final List<_Member> members;
  final int Function(String eduType) feeFor;
  final int total;

  const _FeesPreviewCard({
    required this.leaderEmail,
    required this.leaderEduType,
    required this.leaderFee,
    required this.members,
    required this.feeFor,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline.withOpacity(.25);

    final rows = <_FeeRow>[
      _FeeRow('You (Leader)', leaderEduType, leaderFee),
      ...List.generate(members.length, (i) {
        final m = members[i];
        return _FeeRow('Member ${i + 1}', m.eduType, feeFor(m.eduType));
      }),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final wide = c.maxWidth >= 640;

          final header = LayoutBuilder(
            builder: (ctx2, c2) {
              final narrow = c2.maxWidth < 360;
              final title = Text(
                'Registration Fees (For Reference)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              );
              final chip = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.amber.withOpacity(.4)),
                ),
                child: const Text('Payment disabled', style: TextStyle(fontSize: 11)),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 6),
                    chip,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(fit: BoxFit.scaleDown, child: chip),
                    ),
                  ),
                ],
              );
            },
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 10),

              if (wide) ...[
                // Table on wide screens
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: const [
                    Expanded(child: Text('Participant')),
                    Expanded(child: Text('Type')),
                    Expanded(child: Align(alignment: Alignment.centerRight, child: Text('Fee (₹)'))),
                    Expanded(child: Align(alignment: Alignment.centerRight, child: Text('Notes'))),
                  ]),
                ),
                const SizedBox(height: 6),

                for (final r in rows)
                  _feesRow(
                    theme: theme,
                    a: r.participant,
                    b: r.type,
                    c: '₹${r.fee}',
                    d: r.type == 'graduate' ? 'Graduate fee' : 'Undergraduate fee',
                  ),

                const SizedBox(height: 8),
                _feesTotal(theme: theme, total: total),
              ] else ...[
                // Cards on narrow screens
                for (final r in rows) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                      color: theme.colorScheme.surfaceVariant.withOpacity(.10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(r.participant, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.type,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text('₹${r.fee}', style: theme.textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            r.type == 'graduate' ? 'Graduate fee' : 'Undergraduate fee',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _feesTotal(theme: theme, total: total),
              ],

              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Payment integration is currently disabled. Registration will be submitted without payment.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _feesRow({
    required ThemeData theme,
    required String a,
    required String b,
    required String c,
    required String d,
  }) {
    final subStyle =
        theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Row(
        children: [
          Expanded(child: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(child: Text(b, maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(d, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feesTotal({required ThemeData theme, required int total}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceVariant.withOpacity(.15),
      ),
      child: Row(children: [
        const Expanded(child: Text('Total')),
        const Expanded(child: SizedBox()),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('₹$total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ),
        const Expanded(child: SizedBox()),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline.withOpacity(.25);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------- Safe network image (prevents statusCode: 0 crash) ---------------------- */

class NetImageSafe extends StatelessWidget {
  final String? url;
  final double aspectRatio; // keep layout stable while loading
  final BorderRadius? radius;

  const NetImageSafe({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? BorderRadius.circular(12);
    return ClipRRect(
      borderRadius: r,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: (url == null || url!.isEmpty)
            ? _placeholder(context)
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
                loadingBuilder: (c, w, e) => e == null ? w : _placeholder(context),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.25),
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}
