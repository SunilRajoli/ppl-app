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
    final label = '${role[0].toUpperCase()}${role.substring(1)} Directory';
    final border = theme.colorScheme.outline.withOpacity(0.15);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          label,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Column(
                          children: [
                            // Stats Header
                            _buildStatsHeader(theme, role),

                            const SizedBox(height: 20),

                            // Search Section
                            _buildSearchSection(theme, role),

                            // Loading and Error States
                            if (_loading) _buildLoadingState(theme, role),
                            if (_error != null) _buildErrorState(theme),

                            const SizedBox(height: 20),

                            // Invite Section (admins only)
                            if ((_me?['role'] ?? '').toString().toLowerCase() == 'admin' && role == 'admin')
                              _buildInviteSection(theme),

                            if (role == 'admin') const SizedBox(height: 20),

                            // User List
                            _buildUserList(theme, role),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Component methods for better organization
  Widget _buildStatsHeader(ThemeData theme, String role) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary.withOpacity(0.1), theme.colorScheme.primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.groups_2_outlined, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${role[0].toUpperCase()}${role.substring(1)} Directory',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage and view all $role users',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_filtered.length} users',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme, String role) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Search Users',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by name, email, college, or company...',
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
          if (_q.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.filter_list, color: theme.colorScheme.onSurfaceVariant, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_filtered.length} results for "$_q"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, String role) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Loading $role users...', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade400)),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite New Admin', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          
          // Email field - full width
          TextField(
            controller: _inviteEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Email address',
              prefixIcon: const Icon(Icons.mail_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Name field - full width
          TextField(
            controller: _inviteNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Full name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Send button - full width
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _inviting ? null : _inviteAdmin,
              child: Text(_inviting ? 'Sending...' : 'Send Invite'),
            ),
          ),
          
          if (_inviteMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _inviteMsg!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _inviteMsg!.toLowerCase().contains('error') ? Colors.red.shade400 : Colors.green.shade400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserList(ThemeData theme, String role) {
    if (_filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _q.isEmpty ? 'No users found' : 'No results for "$_q"',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              _q.isEmpty ? 'No $role users have been registered yet' : 'Try adjusting your search terms',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _filtered.asMap().entries.map((entry) {
        final index = entry.key;
        final user = entry.value;
        return _buildUserCard(theme, user, index + 1);
      }).toList(),
    );
  }

  Widget _buildUserCard(ThemeData theme, Map<String, dynamic> user, int number) {
    final id = (user['id'] ?? user['_id'] ?? '').toString();
    final name = (user['name'] ?? '—').toString();
    final email = (user['email'] ?? '—').toString();
    final meta = (user['college'] ?? user['company_name'] ?? user['firm_name'] ?? '').toString();
    final verified = (user['is_verified'] == true) || (user['verified'] == true);
    final open = (user['__open'] == true);

    final meRole = (_me?['role'] ?? '').toString().toLowerCase();
    final meId = (_me?['id'] ?? _me?['_id'] ?? '').toString();
    final canDelete = meRole == 'admin' && meId.isNotEmpty && meId != id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: open 
            ? theme.colorScheme.primary.withOpacity(0.3)
            : theme.colorScheme.outline.withOpacity(0.1),
          width: open ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => user['__open'] = !open),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Number badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: verified 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                verified ? 'V' : 'P',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: verified ? Colors.green.shade700 : Colors.orange.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Actions
                  Row(
                    children: [
                      if (canDelete) ...[
                        IconButton(
                          onPressed: () => _deleteUser(id, name),
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(
                        open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (open) _buildUserDetails(theme, user),
        ],
      ),
    );
  }

  Widget _buildUserDetails(ThemeData theme, Map<String, dynamic> user) {
    final entries = <MapEntry<String, String>>[];
    user.forEach((key, value) {
      final k = key.toString();
      if (k.startsWith('__')) return;
      if (_isSensitive(k)) return;
      entries.add(MapEntry(k, value?.toString() ?? ''));
    });
    entries.sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'User Details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      _prettyKey(e.key),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.value.isEmpty ? '—' : e.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
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
