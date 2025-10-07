// lib/screens/competitions/competition_register_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';

class CompetitionRegisterScreen extends StatefulWidget {
  final String? competitionId;

  const CompetitionRegisterScreen({super.key, this.competitionId});

  @override
  State<CompetitionRegisterScreen> createState() => _CompetitionRegisterScreenState();
}

class _CompetitionRegisterScreenState extends State<CompetitionRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _competition;

  String _registrationType = 'individual';
  final _teamNameCtrl = TextEditingController();
  final _abstractCtrl = TextEditingController();
  final _memberEmailCtrl = TextEditingController();
  final List<String> _memberEmails = <String>[];

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  String get _idFromRouterOrParam {
    final passed = widget.competitionId;
    if (passed != null && passed.isNotEmpty) return passed;
    final id = GoRouterState.of(context).pathParameters['id'];
    return id ?? '';
  }

  int get _maxTeamSize {
    final raw = _competition;
    final v = raw?['max_team_size'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 1;
    return 1;
  }

  int get _seatsRemaining {
    final raw = _competition;
    final v = raw?['seats_remaining'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

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

  Future<void> _ensureAuthAndLoad() async {
    if (_loading == false && _competition != null) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    final id = _idFromRouterOrParam;
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing competition ID';
      });
      return;
    }

    await _loadCompetition(id);
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _abstractCtrl.dispose();
    _memberEmailCtrl.dispose();
    _anim.dispose();
    super.dispose();
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

  bool _isValidEmail(String email) {
    final s = email.trim();
    final reg = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
    return reg.hasMatch(s);
  }

  void _addMemberEmail() {
    final email = _memberEmailCtrl.text.trim();
    if (email.isEmpty) {
      _toast('Please enter an email address');
      return;
    }
    if (!_isValidEmail(email)) {
      _toast('Please enter a valid email address');
      return;
    }
    if (_memberEmails.contains(email)) {
      _toast('Email already added');
      return;
    }
    if (_memberEmails.length + 1 >= _maxTeamSize) {
      _toast('Maximum team size is $_maxTeamSize');
      return;
    }
    setState(() {
      _memberEmails.add(email);
      _memberEmailCtrl.clear();
    });
  }

  void _removeMemberEmailAt(int index) {
    setState(() {
      _memberEmails.removeAt(index);
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _handleSubmit() async {
    if (_competition == null) return;
    final id = _idFromRouterOrParam;

    if (_registrationType == 'team' && _teamNameCtrl.text.trim().isEmpty) {
      _toast('Team name is required for team registration');
      return;
    }

    if (_seatsRemaining <= 0) {
      _toast('No seats remaining for this competition');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{
        'type': _registrationType,
        if (_registrationType == 'team') 'team_name': _teamNameCtrl.text.trim(),
        if (_memberEmails.isNotEmpty) 'member_emails': _memberEmails,
        if (_abstractCtrl.text.trim().isNotEmpty) 'abstract': _abstractCtrl.text.trim(),
      };

      final res = await _api.registerForCompetition(id, payload);
      final ok = (res is Map) ? (res['success'] == true) : false;

      if (ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration submitted')),
        );
        // ✅ Return true to signal success
        context.pop(true);
      } else {
        setState(() {
          _error = (res is Map ? res['message'] as String? : null) ?? 'Registration failed';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Register'),
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
                              _HeaderCard(
                                title: 'Register for Competition',
                                subtitle: '${_competition?['title'] ?? ''}',
                              ),
                              const SizedBox(height: 12),
                              _InfoCard(competition: _competition!),
                              const SizedBox(height: 12),
                              _formSection(theme),
                            ],
                          ),
                        ),
                      ),
                    )),
        ),
      ),
    );
  }

  Widget _formSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Registration Type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (ctx, c) {
              return Row(
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
                        backgroundColor:
                            _registrationType == 'team' ? theme.colorScheme.surfaceVariant.withOpacity(.35) : null,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          if (_registrationType == 'team') ...[
            Text('Team Name', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            _TextField(
              controller: _teamNameCtrl,
              hint: 'Enter your team name',
              leading: Icons.badge_outlined,
            ),
            const SizedBox(height: 14),

            Text('Team Members (by email)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _TextField(
                    controller: _memberEmailCtrl,
                    hint: 'Add member email address',
                    keyboardType: TextInputType.emailAddress,
                    leading: Icons.alternate_email,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _addMemberEmail,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),
              ],
            ),
            if (_memberEmails.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Team Members (${_memberEmails.length})',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < _memberEmails.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined, size: 16),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(_memberEmails[i], overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _removeMemberEmailAt(i),
                            child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
          ],

          Text('Project Abstract (optional)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          _MultilineField(
            controller: _abstractCtrl,
            hint: 'Describe your project idea, approach, or solution...',
            leading: Icons.description_outlined,
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
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
              onPressed: _submitting ? null : _handleSubmit,
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
    );
  }
}

/* ---------------------- Small building blocks ---------------------- */

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.groups, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> competition;
  const _InfoCard({required this.competition});

  String _fmtDate(dynamic d) {
    try {
      final dt = DateTime.tryParse('$d');
      if (dt == null) return '—';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = competition['start_date'];
    final end = competition['end_date'];
    final seats = _asInt(competition['seats_remaining']);
    final teamLimit = _asInt(competition['max_team_size']);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((competition['description'] ?? '').toString().isNotEmpty) ...[
            Text(
              competition['description'],
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(icon: Icons.calendar_today, label: '${_fmtDate(start)} — ${_fmtDate(end)}'),
              _Pill(icon: Icons.tag, label: 'Seats: $seats'),
              _Pill(icon: Icons.groups, label: 'Team limit: ${teamLimit > 0 ? teamLimit : 1}'),
            ],
          ),
        ],
      ),
    );
  }
}

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
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final IconData? leading;

  const _TextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
              ),
            ),
          ),
        ],
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
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
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
              ),
            ),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
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