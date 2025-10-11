import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';

class RoleListScreen extends StatefulWidget {
  final String role; // 'student' | 'hiring' | 'investor' | 'admin'
  const RoleListScreen({super.key, required this.role});

  @override
  State<RoleListScreen> createState() => _RoleListScreenState();
}

class _RoleListScreenState extends State<RoleListScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  String _q = '';

  // Invite admin state
  bool _inviting = false;
  String? _inviteMsg;
  final _inviteNameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();

  // Delete state
  bool _deleting = false;
  String? _deletingId;

  // Current logged-in user (for admin + not-self checks)
  Map<String, dynamic>? _me;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMe();
      await _fetch();
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _inviteNameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    _debounce?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final res = await _api.getProfile();
      // expect { success, data: { user } } OR { user } OR { data }
      final u = (res is Map)
          ? (res['data']?['user'] ?? res['user'] ?? res['data'])
          : null;
      if (u is Map) {
        setState(() => _me = Map<String, dynamic>.from(u));
      }
    } catch (_) {
      // non-blocking
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _inviteMsg = null;
    });

    try {
      dynamic res;
      if (widget.role.toLowerCase() == 'admin') {
        res = await _api.getAdminList();
      } else {
        res = await _api.getUsersByRole(widget.role);
      }

      final rawList = res is Map
          ? (res['data']?['admins'] ??
              res['admins'] ??
              res['data']?['users'] ??
              res['users'] ??
              res['data'])
          : null;

      final list = (rawList is List)
          ? rawList.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      for (int i = 0; i < list.length; i++) {
        list[i]['__rank'] = i + 1;
        list[i]['__open'] = false;
      }

      setState(() {
        _users = list;
        _applySearch();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _q = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(_applySearch);
    });
  }

  void _applySearch() {
    final query = _q.trim().toLowerCase();
    if (query.isEmpty) {
      _filtered = List<Map<String, dynamic>>.from(_users);
      return;
    }
    bool matches(Map<String, dynamic> u) {
      String s(dynamic v) => v == null ? '' : v.toString().toLowerCase();
      return [
        s(u['name']),
        s(u['email']),
        s(u['college']),
        s(u['company_name']),
        s(u['firm_name']),
        s(u['phone']),
      ].any((f) => f.contains(query));
    }
    _filtered = _users.where(matches).toList();
  }

  String _prettyKey(String raw) {
    final norm = raw.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    final parts = norm.split(' ');
    return parts.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  bool _isSensitive(String k) {
    final s = k.toLowerCase();
    return s.contains('password') ||
        s.contains('token') ||
        s.contains('otp') ||
        s.contains('secret') ||
        s.contains('hash') ||
        s.contains('salt');
  }

  String _initialsOf(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return 'U';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p[0]).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _inviteAdmin() async {
    final name = _inviteNameCtrl.text.trim();
    final email = _inviteEmailCtrl.text.trim();

    if (name.length < 2) {
      setState(() => _inviteMsg = 'Name must be at least 2 characters');
      return;
    }
    final emailOk = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
    if (!emailOk) {
      setState(() => _inviteMsg = 'Enter a valid email');
      return;
    }

    try {
      setState(() {
        _inviting = true;
        _inviteMsg = null;
      });
      final res = await _api.inviteAdmin(name: name, email: email);
      if (res is Map && (res['success'] == true)) {
        setState(() => _inviteMsg = 'Invitation sent to $email');
        await _fetch();
      } else {
        setState(() => _inviteMsg =
            (res is Map ? (res['message']?.toString() ?? 'Failed to invite') : 'Failed to invite'));
      }
    } catch (e) {
      setState(() => _inviteMsg = 'Error: $e');
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _deleteUser(String userId, String name) async {
    if (_deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Delete user "${name.isEmpty ? userId : name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deleting = true;
      _deletingId = userId;
    });

    try {
      dynamic res;
      try {
        res = await _api.deleteUser(userId);
      } catch (_) {
        // fallback to soft-deactivate if hard delete not allowed
        res = await _api.deactivateUser(userId);
      }

      final ok = (res is Map && (res['success'] == true)) || res == null;
      if (!ok) {
        final msg = (res is Map ? (res['message']?.toString() ?? 'Failed to delete user') : 'Failed to delete user');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }

      // remove locally
      setState(() {
        _users.removeWhere((u) => '${u['id']}' == userId);
        _filtered.removeWhere((u) => '${u['id']}' == userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
          _deletingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = widget.role.toLowerCase();
    final label = '${role[0].toUpperCase()}${role.substring(1)} • Directory';
    final border = theme.colorScheme.outline.withOpacity(0.25);

    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const _NoGlowBehavior(),
          child: RefreshIndicator(
            onRefresh: _fetch,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: border),
                                ),
                                child: Icon(Icons.groups_2_outlined,
                                    color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(label,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        )),
                                    Text('Browse and manage $role users',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Search + Count
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: border),
                                    ),
                                    child: Text(role,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        )),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: border),
                                    ),
                                    child: Text('${_filtered.length} total',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        )),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: 'Search name, email, college/company…',
                                  prefixIcon: const Icon(Icons.search),
                                  isDense: false,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              if (_loading)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('Loading $role users…',
                                          style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red.shade300),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_error!,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: Colors.red.shade300,
                                            )),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: _fetch,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Invite (admins only)
                        if (( _me?['role'] ?? '' ).toString().toLowerCase() == 'admin' && role == 'admin')
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Invite Admin',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _inviteNameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: 'Full name',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _inviteEmailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (_) => setState(() => _inviteMsg = null),
                                  decoration: InputDecoration(
                                    hintText: 'Email address',
                                    errorText: (_inviteMsg != null &&
                                            _inviteMsg!.toLowerCase().contains('email'))
                                        ? _inviteMsg
                                        : null,
                                    prefixIcon: const Icon(Icons.mail_outline),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: _inviting ? null : _inviteAdmin,
                                  child: Text(_inviting ? 'Sending…' : 'Send Invite'),
                                ),
                                if (_inviteMsg != null &&
                                    !_inviteMsg!.toLowerCase().contains('email'))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _inviteMsg!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: _inviteMsg!.toLowerCase().contains('error') ||
                                                _inviteMsg!.toLowerCase().contains('fail')
                                            ? Colors.red.shade300
                                            : Colors.green.shade400,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        if (role == 'admin') const SizedBox(height: 12),

                        // List
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: _filtered.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _q.isEmpty ? 'No users found.' : 'No results for “$_q”.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: List.generate(_filtered.length, (i) {
                                    final u = _filtered[i];
                                    final id = (u['id'] ?? u['_id'] ?? '$i').toString();
                                    final name = (u['name'] ?? '—').toString();
                                    final email = (u['email'] ?? '—').toString();
                                    final meta = (u['college'] ?? u['company_name'] ?? u['firm_name'] ?? '').toString();
                                    final verified = (u['is_verified'] == true) || (u['verified'] == true);
                                    final rank = (u['__rank'] ?? (i + 1)).toString();
                                    final open = (u['__open'] == true);
                                    final initials = _initialsOf(name);

                                    final meRole = (_me?['role'] ?? '').toString().toLowerCase();
                                    final meId = (_me?['id'] ?? _me?['_id'] ?? '').toString();
                                    final canDelete = meRole == 'admin' && meId.isNotEmpty && meId != id;

                                    final entries = <MapEntry<String, String>>[];
                                    u.forEach((key, value) {
                                      final k = key.toString();
                                      if (k.startsWith('__')) return;
                                      if (_isSensitive(k)) return;
                                      entries.add(MapEntry(k, value?.toString() ?? ''));
                                    });
                                    entries.sort((a, b) => a.key.compareTo(b.key));

                                    return KeyedSubtree(
                                      key: ValueKey('user-$id'),
                                      child: Column(
                                        children: [
                                          InkWell(
                                            onTap: () => setState(() => u['__open'] = !open),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.surfaceContainerHighest,
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: border),
                                                    ),
                                                    child: Text(rank,
                                                        style: theme.textTheme.labelLarge
                                                            ?.copyWith(fontWeight: FontWeight.w800)),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.surfaceContainerHighest,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: border),
                                                    ),
                                                    child: Text(initials,
                                                        style: theme.textTheme.labelLarge
                                                            ?.copyWith(fontWeight: FontWeight.w800)),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          name,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: theme.textTheme.bodyLarge?.copyWith(
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          email,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: theme.textTheme.bodySmall,
                                                        ),
                                                        if (meta.isNotEmpty)
                                                          Text(
                                                            meta,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: theme.textTheme.labelSmall?.copyWith(
                                                              color: theme.colorScheme.onSurfaceVariant,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Status chip
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: (verified ? Colors.green : Colors.amber).withOpacity(.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: (verified ? Colors.green : Colors.amber).withOpacity(.3),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      verified ? 'Verified' : 'Pending',
                                                      style: const TextStyle(fontSize: 11),
                                                    ),
                                                  ),

                                                  // Delete (admin & not-self)
                                                  if (canDelete) ...[
                                                    const SizedBox(width: 6),
                                                    OutlinedButton(
                                                      onPressed: (_deleting && _deletingId == id)
                                                          ? null
                                                          : () => _deleteUser(id, name),
                                                      style: OutlinedButton.styleFrom(
                                                        side: BorderSide(color: Colors.red.withOpacity(.3)),
                                                        backgroundColor: Colors.red.withOpacity(.08),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        minimumSize: const Size(0, 0),
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                      child: Text(
                                                        (_deleting && _deletingId == id) ? 'Deleting…' : 'Delete',
                                                        style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B)),
                                                      ),
                                                    ),
                                                  ],

                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    open ? Icons.expand_less : Icons.expand_more,
                                                    size: 20,
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (open)
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: border),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Details',
                                                        style: theme.textTheme.titleSmall?.copyWith(
                                                            fontWeight: FontWeight.w700)),
                                                    const SizedBox(height: 8),
                                                    ...entries.map((e) => Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                                          child: Row(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              SizedBox(
                                                                width: 140,
                                                                child: Text(
                                                                  _prettyKey(e.key),
                                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                                    color: theme.colorScheme.onSurfaceVariant,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Expanded(
                                                                child: Text(
                                                                  e.value.isEmpty ? '—' : e.value,
                                                                  style: theme.textTheme.bodySmall,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (i != _filtered.length - 1)
                                            Divider(height: 1, color: border.withOpacity(.48)),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // no glow
  }
  @override
  ScrollbarThemeData getScrollbarTheme(BuildContext context) {
    return const ScrollbarThemeData(thickness: WidgetStatePropertyAll(0)); // hide scrollbar
  }
}
