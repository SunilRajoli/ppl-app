// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/models/user_model.dart' show User;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _error;

  // common
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // student
  final _collegeCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  // hiring
  final _orgCtrl = TextEditingController();
  final _teamSizeCtrl = TextEditingController();

  // investor
  final _firmCtrl = TextEditingController();
  final _stageCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // skills
  final _skillCtrl = TextEditingController();
  final FocusNode _skillFocus = FocusNode();
  List<String> _skills = <String>[];

  // NEW: extra profile fields (matching React)
  String _gender =
      'prefer_not_to_say'; // male|female|non_binary|prefer_not_to_say
  String _eduType = 'undergraduate'; // undergraduate|graduate|other
  final _workExpCtrl = TextEditingController(); // years (only for graduate)

  // Read-only consent + active status
  String? _agreedTncAt; // ISO string
  String? _agreedPrivacyAt; // ISO string
  bool? _isActive; // bool

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  User? _user;
  Map<String, dynamic>? _rawUser;

  String get _role => (_user?.role ?? '')
      .trim()
      .toLowerCase(); // student | hiring | investor | admin

  bool get isStudent => _role == 'student';
  bool get isHiring => _role == 'hiring';
  bool get isInvestor => _role == 'investor';
  bool get isAdmin => _role == 'admin';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _countryCtrl.dispose();

    _collegeCtrl.dispose();
    _branchCtrl.dispose();
    _yearCtrl.dispose();

    _orgCtrl.dispose();
    _teamSizeCtrl.dispose();

    _firmCtrl.dispose();
    _stageCtrl.dispose();
    _websiteCtrl.dispose();

    _skillCtrl.dispose();
    _skillFocus.dispose();

    _workExpCtrl.dispose();

    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // seed from provider for instant UI
      final auth = context.read<AuthProvider>();
      if (auth.user != null) _applyUser(auth.user!, null);

      // fetch fresh profile
      final res = await _api.getProfile();
      final data = res?['data'] ?? res;
      final userMap = (data?['user'] ?? data) as Map<String, dynamic>?;
      if (userMap != null) {
        final remote = User.fromJson(userMap);
        _applyUser(remote, userMap);
        context.read<AuthProvider>().setUser(remote); // keep provider in sync
      }
      _anim.forward();
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyUser(User u, Map<String, dynamic>? raw) {
    _user = u;
    _rawUser = raw;

    // common
    _nameCtrl.text = u.name;
    _phoneCtrl.text = (raw?['phone'] ?? u.toJson()['phone'] ?? '').toString();
    _countryCtrl.text =
        (raw?['country'] ?? u.toJson()['country'] ?? '').toString();

    // student
    _collegeCtrl.text = u.college ?? '';
    _branchCtrl.text = u.branch ?? '';
    _yearCtrl.text = (u.year?.toString() ?? '');

    // hiring
    _orgCtrl.text =
        (raw?['company_name'] ?? raw?['org'] ?? u.toJson()['org'] ?? '')
            .toString();
    _teamSizeCtrl.text = (raw?['team_size'] ?? '').toString();

    // investor
    _firmCtrl.text = (raw?['firm_name'] ?? '').toString();
    _stageCtrl.text = (raw?['investment_stage'] ?? '').toString();
    _websiteCtrl.text =
        (raw?['website'] ?? raw?['company_website'] ?? '').toString();

    // skills
    _skills = _readSkills(raw ?? u.toJson());

    // NEW: extra fields
    _gender = (raw?['gender'] ?? u.toJson()['gender'] ?? 'prefer_not_to_say')
        .toString();
    _eduType = (raw?['edu_type'] ?? u.toJson()['edu_type'] ?? 'undergraduate')
        .toString();

    final workExpAny =
        raw?['work_experience_years'] ?? u.toJson()['work_experience_years'];
    _workExpCtrl.text = workExpAny == null ? '' : workExpAny.toString();

    _agreedTncAt =
        (raw?['agreed_tnc_at'] ?? u.toJson()['agreed_tnc_at'])?.toString();
    _agreedPrivacyAt =
        (raw?['agreed_privacy_at'] ?? u.toJson()['agreed_privacy_at'])
            ?.toString();
    final activeAny = raw?['is_active'] ?? u.toJson()['is_active'];
    _isActive = activeAny is bool
        ? activeAny
        : (activeAny?.toString().toLowerCase() == 'true');

    setState(() {});
  }

  List<String> _readSkills(Map<String, dynamic>? raw) {
    final v = raw?['skills'];
    if (v == null) return <String>[];
    if (v is List) {
      return v
          .map((e) => (e ?? '').toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (v is String) {
      return v
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  void _toggleEditing() {
    setState(() {
      _editing = !_editing;
      _error = null;
      if (!_editing && _user != null) _applyUser(_user!, _rawUser);
    });
  }

  void _addSkill() {
    final input = _skillCtrl.text.trim();
    if (input.isEmpty) return;

    final parts =
        input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final existingLower = _skills.map((s) => s.toLowerCase()).toSet();
    final merged = List<String>.of(_skills);
    for (final p in parts) {
      if (!existingLower.contains(p.toLowerCase())) {
        merged.add(p); // keep entered casing
        existingLower.add(p.toLowerCase());
      }
    }
    setState(() => _skills = merged);
    _skillCtrl.clear();
    _skillFocus.requestFocus();
  }

  void _removeSkill(String s) {
    setState(() => _skills = _skills.where((e) => e != s).toList());
  }

  Future<void> _save() async {
    if (_user == null) return;

    FocusScope.of(context).unfocus(); // ensure latest values + better UX

    // parse ints safely
    int? year;
    if (_yearCtrl.text.trim().isNotEmpty) {
      year = int.tryParse(_yearCtrl.text.trim());
      if (year == null) {
        setState(() => _error = 'Year must be a number');
        return;
      }
    }

    int? teamSize;
    if (_teamSizeCtrl.text.trim().isNotEmpty) {
      teamSize = int.tryParse(_teamSizeCtrl.text.trim());
      if (teamSize == null) {
        setState(() => _error = 'Team size must be a number');
        return;
      }
    }

    int? workExp;
    if (_eduType == 'graduate') {
      if (_workExpCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Please enter your work experience (years).');
        return;
      }
      workExp = int.tryParse(_workExpCtrl.text.trim());
      if (workExp == null || workExp < 0 || workExp > 60) {
        setState(() => _error = 'Work experience must be between 0 and 60.');
        return;
      }
    }

    // build payload based on role + NEW fields
    final payload = <String, dynamic>{
      // common
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'skills': _skills,

      // NEW fields (present in React)
      'gender': _gender,
      'edu_type': _eduType,
      'work_experience_years': _eduType == 'graduate' ? (workExp ?? 0) : 0,

      // role-specific
      if (isStudent) ...{
        'college': _collegeCtrl.text.trim(),
        'branch': _branchCtrl.text.trim(),
        if (year != null) 'year': year,
      },
      if (isHiring) ...{
        'company_name': _orgCtrl.text.trim(),
        if (teamSize != null) 'team_size': teamSize,
        'company_website': _websiteCtrl.text.trim(),
      },
      if (isInvestor) ...{
        'firm_name': _firmCtrl.text.trim(),
        'investment_stage': _stageCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
      },
    };

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final res = await _api.updateProfile(payload);
      final updated = (res?['data']?['user']) ?? res?['user'] ?? res?['data'];

      // merge local + raw + payload + server-updated
      final mergedMap = <String, dynamic>{
        ..._user!.toJson(),
        if (_rawUser != null) ..._rawUser!,
        ...payload,
        if (updated is Map<String, dynamic>) ...updated,
      };
      final nextUser = User.fromJson(mergedMap);

      // push into provider & reflect locally
      context.read<AuthProvider>().setUser(nextUser);
      _applyUser(nextUser, mergedMap);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      setState(() => _editing = false);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (ok != true) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.go('/login');
  }

  String _prettyInitials() {
    final n = (_user?.name ?? '').trim();
    if (n.isEmpty) return 'U';
    final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return parts.length >= 2
        ? (parts.first[0] + parts.last[0]).toUpperCase()
        : n[0].toUpperCase();
  }

  String _fmtIso(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withOpacity(0.25);

    final initials = _prettyInitials();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), elevation: 0),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ===== Header card =====
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.12),
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (_user?.name ?? '').isNotEmpty
                                            ? _user!.name
                                            : '-',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(_user?.email ?? '-',
                                          style: theme.textTheme.bodySmall),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _Pill(
                                            icon: Icons.shield_outlined,
                                            label: (_user?.role ?? 'user')
                                                .toUpperCase(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: _editing ? 'Cancel' : 'Edit',
                                  onPressed: _toggleEditing,
                                  icon: Icon(_editing
                                      ? Icons.close
                                      : Icons.edit_outlined),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 12),

                          // ===== Details card (role-aware) =====
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Column(
                              children: [
                                // common
                                _RowField.readOnly(
                                  label: 'Email',
                                  value: _user?.email ?? '-',
                                  icon: Icons.mail_outline,
                                ),
                                const SizedBox(height: 10),
                                _RowField(
                                  label: 'Full name',
                                  icon: Icons.person_outline,
                                  editing: _editing,
                                  controller: _nameCtrl,
                                  value: _user?.name ?? '',
                                  hint: 'Enter your full name',
                                  textCapitalization: TextCapitalization.words,
                                ),
                                const SizedBox(height: 10),
                                _RowField(
                                  label: 'Phone',
                                  icon: Icons.phone_outlined,
                                  editing: _editing,
                                  controller: _phoneCtrl,
                                  value: _phoneCtrl.text,
                                  keyboardType: TextInputType.phone,
                                  hint: 'Contact number',
                                  hideIfEmptyWhenNotEditing: true,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _RowField(
                                  label: 'Country',
                                  icon: Icons.public_outlined,
                                  editing: _editing,
                                  controller: _countryCtrl,
                                  value: _countryCtrl.text,
                                  hint: 'Country',
                                  hideIfEmptyWhenNotEditing: true,
                                  textCapitalization: TextCapitalization.words,
                                ),

                                // student block
                                if (isStudent) ...[
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'College',
                                    icon: Icons.school_outlined,
                                    editing: _editing,
                                    controller: _collegeCtrl,
                                    value: _collegeCtrl.text,
                                    hint: 'College name',
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'Branch',
                                    icon: Icons.alt_route_outlined,
                                    editing: _editing,
                                    controller: _branchCtrl,
                                    value: _branchCtrl.text,
                                    hint: 'e.g. Computer Science',
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'Year',
                                    icon: Icons.tag_outlined,
                                    editing: _editing,
                                    controller: _yearCtrl,
                                    value: _yearCtrl.text,
                                    keyboardType: TextInputType.number,
                                    hint: 'e.g. 3',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                  ),
                                ],

                                // hiring block
                                if (isHiring) ...[
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'Company',
                                    icon: Icons.business_outlined,
                                    editing: _editing,
                                    controller: _orgCtrl,
                                    value: _orgCtrl.text,
                                    hint: 'Company name',
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'Team size',
                                    icon: Icons.groups_outlined,
                                    editing: _editing,
                                    controller: _teamSizeCtrl,
                                    value: _teamSizeCtrl.text,
                                    keyboardType: TextInputType.number,
                                    hint: 'e.g. 12',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    hideIfEmptyWhenNotEditing: true,
                                  ),
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'Company website',
                                    icon: Icons.link_outlined,
                                    editing: _editing,
                                    controller: _websiteCtrl,
                                    value: _websiteCtrl.text,
                                    hint: 'https://example.com',
                                    hideIfEmptyWhenNotEditing: true,
                                  ),
                                ],

                                // investor block
                                if (isInvestor) ...[
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'Firm',
                                    icon: Icons.account_balance_outlined,
                                    editing: _editing,
                                    controller: _firmCtrl,
                                    value: _firmCtrl.text,
                                    hint: 'Firm/Angel name',
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'Stage focus',
                                    icon: Icons.rocket_launch_outlined,
                                    editing: _editing,
                                    controller: _stageCtrl,
                                    value: _stageCtrl.text,
                                    hint: 'e.g. Pre-seed, Seed, Series A',
                                  ),
                                  const SizedBox(height: 10),
                                  _RowField(
                                    label: 'Website',
                                    icon: Icons.link_outlined,
                                    editing: _editing,
                                    controller: _websiteCtrl,
                                    value: _websiteCtrl.text,
                                    hint: 'https://portfolio.example',
                                    hideIfEmptyWhenNotEditing: true,
                                  ),
                                ],

                                const SizedBox(height: 14),

                                // NEW: Gender (dropdown) — available to all
                                _Labeled(
                                  label: 'Gender',
                                  icon: Icons.person_3_outlined,
                                  child: _editing
                                      ? DropdownButtonFormField<String>(
                                          value: _gender,
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'male',
                                                child: Text('Male')),
                                            DropdownMenuItem(
                                                value: 'female',
                                                child: Text('Female')),
                                            DropdownMenuItem(
                                                value: 'non_binary',
                                                child: Text('Non-binary')),
                                            DropdownMenuItem(
                                                value: 'prefer_not_to_say',
                                                child:
                                                    Text('Prefer not to say')),
                                          ],
                                          onChanged: (v) => setState(() =>
                                              _gender =
                                                  v ?? 'prefer_not_to_say'),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                        )
                                      : Text(
                                          _gender.replaceAll('_', ' '),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                ),

                                const SizedBox(height: 10),

                                // NEW: Type (dropdown) + conditional Work Experience
                                _Labeled(
                                  label: 'Type',
                                  icon: Icons.school_outlined,
                                  child: _editing
                                      ? DropdownButtonFormField<String>(
                                          value: _eduType,
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'undergraduate',
                                                child: Text('Undergraduate')),
                                            DropdownMenuItem(
                                                value: 'graduate',
                                                child: Text('Graduate')),
                                            DropdownMenuItem(
                                                value: 'other',
                                                child: Text('Other')),
                                          ],
                                          onChanged: (v) => setState(() =>
                                              _eduType = v ?? 'undergraduate'),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                        )
                                      : Text(_eduType,
                                          style: theme.textTheme.bodyMedium),
                                ),

                                if (_eduType == 'graduate') ...[
                                  const SizedBox(height: 10),
                                  _Labeled(
                                    label: 'Work Experience (years)',
                                    icon: Icons.work_outline,
                                    child: _editing
                                        ? TextField(
                                            controller: _workExpCtrl,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                            decoration: InputDecoration(
                                              hintText: 'e.g., 2',
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                            ),
                                          )
                                        : Text(
                                            _workExpCtrl.text.isEmpty
                                                ? '—'
                                                : _workExpCtrl.text,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                  ),
                                ],

                                const SizedBox(height: 14),

                                // Skills (available to all)
                                _Labeled(
                                  label: 'Skills',
                                  icon: Icons.tag_outlined,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final s in _skills)
                                            InputChip(
                                              label: Text(s),
                                              onDeleted: _editing
                                                  ? () => _removeSkill(s)
                                                  : null,
                                            ),
                                          if (_editing)
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                  maxWidth: 280),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      focusNode: _skillFocus,
                                                      controller: _skillCtrl,
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: 'Add skill',
                                                        isDense: true,
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 12,
                                                          vertical: 10,
                                                        ),
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                      ),
                                                      onSubmitted: (_) =>
                                                          _addSkill(),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    height: 40,
                                                    child: OutlinedButton(
                                                      onPressed: _addSkill,
                                                      child: const Text('Add'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (_editing)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            'Tip: Add multiple with commas (e.g., React, Flutter, SQL).',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      if (!_editing && _skills.isEmpty)
                                        Text('—',
                                            style: theme.textTheme.bodyMedium),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Read-only consent timestamps + active
                                _Labeled(
                                  label: 'Agreed T&C',
                                  icon: Icons.verified_outlined,
                                  child: Text(_fmtIso(_agreedTncAt),
                                      style: theme.textTheme.bodyMedium),
                                ),
                                const SizedBox(height: 10),
                                _Labeled(
                                  label: 'Agreed Privacy',
                                  icon: Icons.privacy_tip_outlined,
                                  child: Text(_fmtIso(_agreedPrivacyAt),
                                      style: theme.textTheme.bodyMedium),
                                ),
                                const SizedBox(height: 10),
                                _Labeled(
                                  label: 'Active',
                                  icon: Icons.check_circle_outline,
                                  child: Text(_isActive == true ? 'Yes' : 'No',
                                      style: theme.textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ===== Actions =====
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/change-password'),
                                icon: const Icon(Icons.lock_outline),
                                label: const Text('Change Password'),
                              ),
                              const SizedBox(height: 10),
                              _editing
                                  ? FilledButton.icon(
                                      onPressed: _saving ? null : _save,
                                      icon: const Icon(Icons.save_outlined),
                                      label: Text(_saving ? 'Saving…' : 'Save'),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _logout,
                                      icon: const Icon(Icons.logout),
                                      label: const Text('Logout'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                            ],
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

/* -------------------- small UI helpers -------------------- */

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;
  const _Labeled({
    required this.label,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RowField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool editing;
  final TextEditingController? controller;
  final String value;
  final String? hint;
  final TextInputType? keyboardType;
  final bool hideIfEmptyWhenNotEditing;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const _RowField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.editing = false,
    this.controller,
    this.hint,
    this.keyboardType,
    this.hideIfEmptyWhenNotEditing = false,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  const _RowField.readOnly({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  })  : editing = false,
        controller = null,
        hint = null,
        keyboardType = null,
        hideIfEmptyWhenNotEditing = false,
        inputFormatters = null,
        textCapitalization = TextCapitalization.none;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!editing && hideIfEmptyWhenNotEditing && value.isEmpty) {
      return const SizedBox.shrink();
    }
    return _Labeled(
      label: label,
      icon: icon,
      child: editing
          ? TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textCapitalization: textCapitalization,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          : Text(value.isNotEmpty ? value : '—',
              style: theme.textTheme.bodyMedium),
    );
  }
}
