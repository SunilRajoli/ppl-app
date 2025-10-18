
// lib/screens/competitions/competitions_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';

/// -------------------- tiny safe-parsing helpers --------------------
int asInt(dynamic x) {
  if (x == null) return 0;
  if (x is int) return x;
  if (x is num) return x.toInt();
  return int.tryParse('$x') ?? 0;
}

bool asBool(dynamic x) {
  if (x == null) return false;
  if (x is bool) return x;
  if (x is num) return x != 0;
  final s = x.toString().toLowerCase().trim();
  return s == 'true' || s == '1' || s == 'yes';
}

DateTime? asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse('$v');
}

String fmtDate(DateTime? d, {bool withYear = true}) {
  if (d == null) return '—';
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return withYear ? '$dd/$mm/${d.year}' : '$dd/$mm';
}

/// --------------------------- filters ---------------------------
enum CompFilter { all, ongoing, upcoming, completed, myCompetitions }

/// ------------------ hide scrollbar behavior ------------------
class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // no scrollbar widget
  }
}

/// ----------------- optimistic flags persistence -----------------
const _LS_REG = 'ppl:optimistic:registered';
const _LS_SUB = 'ppl:optimistic:submitted';

Future<Set<String>> _loadSet(String key) async {
  try {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(key) ?? const <String>[];
    return list.map((e) => e.toString()).toSet();
  } catch (_) {
    return <String>{};
  }
}

Future<void> _saveSet(String key, Set<String> set) async {
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(key, set.toList());
  } catch (_) {}
}

/// ------------------------- Screen -------------------------
class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  // data
  List<Competition> _competitions = [];
  bool _isLoading = true;
  String? _error;

  // ui state
  bool _refreshing = false;
  CompFilter _active = CompFilter.all;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  // counts
  int _cntOngoing = 0;
  int _cntUpcoming = 0;
  int _cntCompleted = 0;
  int _cntMine = 0; // admin-created-by-me
  int _cntMyComps = 0; // student: i'm registered/submitted

  // admin toggle
  bool _adminMyOnly = false;

  // per-card states
  String? _deletingId;

  // optimistic flags (persisted)
  Set<String> _optimisticRegistered = <String>{};
  Set<String> _optimisticSubmitted = <String>{};

  // animation
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    // load optimistic sets first (like React localStorage)
    final r = await _loadSet(_LS_REG);
    final s = await _loadSet(_LS_SUB);
    if (mounted) {
      setState(() {
        _optimisticRegistered = r;
        _optimisticSubmitted = s;
      });
    }
    await _loadCompetitions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  /// React-style status computed from dates
  String _computeStatus(Competition c) {
    final start = c.startDate ?? asDate(c.extra['start_date']);
    final end = c.endDate ?? asDate(c.extra['end_date']);
    final now = DateTime.now();
    if (start != null && start.isAfter(now)) return 'upcoming';
    if (start != null && end != null && (start.isBefore(now) || start.isAtSameMomentAs(now)) && end.isAfter(now)) {
      return 'ongoing';
    }
    if (end != null && end.isBefore(now)) return 'completed';
    // fallback if only one date missing
    if (start != null && (end == null)) {
      return start.isAfter(now) ? 'upcoming' : 'ongoing';
    }
    return 'upcoming';
  }

  bool _isPostedByMe(Competition c, User? me) {
    if (me == null) return false;
    final raw = c.extra;
    final postedBy = raw['posted_by'] ?? raw['postedBy'] ?? c.sponsor;
    final pid = (postedBy is Map) ? (postedBy['id'] ?? postedBy['_id']) : null;
    final myId = me.id;
    return (pid?.toString() ?? '') == (myId ?? '').toString();
  }

  bool _isMyCompetition(Competition c) {
    final raw = c.extra;
    return asBool(raw['user_registered']) || asBool(raw['user_submitted']);
  }

  Future<void> _loadCompetitions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await _apiService.listCompetitions();
      final data = response['data'] ?? response;
      List<Competition> competitions =
          (data['competitions'] as List? ?? const [])
              .map((e) => Competition.fromJson(e as Map<String, dynamic>))
              .toList();

      // merge normalized server flags + optimistic flags (submitted implies registered)
      competitions = competitions.map((c) {
        final cid = (c.id ?? '').toString();

        final raw = Map<String, dynamic>.from(c.extra);
        final serverRegistered = asBool(
              raw['user_registered'] ??
              raw['user']?['registered'] ??
              raw['registration']?['is_registered'] ??
              raw['user_has_registration']
            ) ||
            (raw['registration_status']?.toString().toLowerCase() == 'registered');

        final serverSubmitted = asBool(
              raw['user_submitted'] ??
              raw['submission']?['exists'] ??
              raw['user_has_submission']
            );

        final optimisticSub = _optimisticSubmitted.contains(cid);
        final optimisticReg = _optimisticRegistered.contains(cid);

        final finalSubmitted = serverSubmitted || optimisticSub;
        final finalRegistered = serverRegistered || optimisticReg || finalSubmitted;

        raw['user_registered'] = finalRegistered;
        raw['user_submitted'] = finalSubmitted;

        return c.copyWith(extra: raw);
      }).toList();

      // compute counts
      final auth = context.read<AuthProvider?>();
      final me = auth?.user;
      int ongoing = 0, upcoming = 0, completed = 0, createdByMe = 0, myComps = 0;
      for (final c in competitions) {
        final s = _computeStatus(c);
        if (s == 'ongoing') ongoing++;
        else if (s == 'upcoming') upcoming++;
        else if (s == 'completed') completed++;

        if (_isPostedByMe(c, me)) createdByMe++;
        if (_isMyCompetition(c)) myComps++;
      }

      if (!mounted) return;
      setState(() {
        _competitions = competitions;
        _cntOngoing = ongoing;
        _cntUpcoming = upcoming;
        _cntCompleted = completed;
        _cntMine = createdByMe;
        _cntMyComps = myComps;
        _isLoading = false;
        _refreshing = false;
      });
      _anim.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _refreshing = true);
    await _loadCompetitions();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {});
    });
  }

  List<Competition> get _filtered {
    final auth = context.read<AuthProvider?>();
    final me = auth?.user;
    final role = (me?.role ?? '').toLowerCase();
    final isAdmin = role == 'admin';
    final isHiring = role == 'hiring';
    final isInvestor = role == 'investor';
    final isStudent = role == 'student' || role == 'user';

    final q = _searchCtrl.text.trim().toLowerCase();
    Iterable<Competition> list = _competitions;

    switch (_active) {
      case CompFilter.ongoing:
        list = list.where((c) => _computeStatus(c) == 'ongoing');
        break;
      case CompFilter.upcoming:
        list = list.where((c) => _computeStatus(c) == 'upcoming');
        break;
      case CompFilter.completed:
        list = list.where((c) => _computeStatus(c) == 'completed');
        break;
      case CompFilter.myCompetitions:
        list = list.where(_isMyCompetition);
        break;
      case CompFilter.all:
        break;
    }

    if (isAdmin && _adminMyOnly) {
      list = list.where((c) => _isPostedByMe(c, me));
    }

    if ((isHiring || isInvestor) && _active == CompFilter.myCompetitions) {
      list = _competitions; // ignore this filter for hiring/investor
    }

    if (q.isNotEmpty) {
      list = list.where((c) {
        final raw = c.extra;
        final sponsor = (raw['sponsor'] ?? c.sponsor ?? '').toString().toLowerCase();
        final tags = c.tags.map((e) => e.toLowerCase());
        return c.title.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q) ||
            sponsor.contains(q) ||
            tags.any((t) => t.contains(q));
      });
    }
    return List<Competition>.from(list);
  }

  /// ----------------------------- UI helpers -----------------------------

  Widget _statusChip(String label, List<Color> gradient, {Color border = const Color(0xFFFFFFFF)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withOpacity(.35)),
        boxShadow: [BoxShadow(color: gradient.last.withOpacity(.25), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _metricButton({
    required String label,
    required int count,
    required bool selected,
    required List<Color> palette,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final ring = palette.last.withOpacity(.30);
    final bg = palette.first.withOpacity(.15);
    final fg = palette.last.withOpacity(.85);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.outline.withOpacity(0.4)
                : Theme.of(context).colorScheme.outline.withOpacity(0.25),
          ),
          boxShadow: selected ? [BoxShadow(color: ring, blurRadius: 10, offset: const Offset(0, 3))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 12, backgroundColor: bg, child: Icon(icon, size: 14, color: fg)),
            const SizedBox(width: 8),
            Text('$count', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  int _cntCreatedByMe(User? me) {
    if (me == null) return 0;
    return _competitions.where((c) => _isPostedByMe(c, me)).length;
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.read<AuthProvider?>()?.user;
    final role = (me?.role ?? '').toLowerCase();
    final isAdmin = role == 'admin';
    final isStudent = role == 'student' || role == 'user';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + create button
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Competitions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Discover and join exciting competitions',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (isAdmin)
                FilledButton.icon(
                  onPressed: () async {
                    final res = await context.push('/competition/create');
                    if (res is Map && res['refreshCompetitions'] == true) _refresh();
                  },
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Create'),
                ),
            ],
          ),
        ),

        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _adminMyOnly = !_adminMyOnly),
              icon: const Icon(Icons.person_outline),
              label: Text('My Competitions (${_cntCreatedByMe(me)})'),
              style: OutlinedButton.styleFrom(
                backgroundColor: _adminMyOnly ? theme.colorScheme.surface : null,
                side: BorderSide(
                  color: _adminMyOnly
                      ? theme.colorScheme.primary.withOpacity(0.35)
                      : theme.colorScheme.outline.withOpacity(0.35),
                ),
              ),
            ),
          ),

        // Metrics (Ongoing, Upcoming, Completed) + My Competitions
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricButton(
              label: 'Ongoing',
              count: _cntOngoing,
              selected: _active == CompFilter.ongoing,
              palette: const [Colors.green, Color(0xFF10B981)],
              icon: Icons.show_chart,
              onTap: () => setState(() => _active = CompFilter.ongoing),
            ),
            _metricButton(
              label: 'Upcoming',
              count: _cntUpcoming,
              selected: _active == CompFilter.upcoming,
              palette: const [Colors.amber, Color(0xFFFF9800)],
              icon: Icons.schedule_outlined,
              onTap: () => setState(() => _active = CompFilter.upcoming),
            ),
            _metricButton(
              label: 'Completed',
              count: _cntCompleted,
              selected: _active == CompFilter.completed,
              palette: const [Colors.grey, Color(0xFF64748B)],
              icon: Icons.check_circle_outline,
              onTap: () => setState(() => _active = CompFilter.completed),
            ),
            if (_active != CompFilter.all)
              TextButton.icon(
                onPressed: () => setState(() => _active = CompFilter.all),
                icon: const Icon(Icons.close),
                label: const Text('Clear filter'),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // Search
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search competitions, sponsors, tags...',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(.6),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: (_searchCtrl.text.isNotEmpty)
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear',
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ----------------------------- Card -----------------------------
  Widget _buildCompetitionCard(Competition c) {
    final theme = Theme.of(context);
    final raw = c.extra;

    final status = _computeStatus(c);
    // gradient definitions (mirroring React BADGE)
    List<Color> pillGrad;
    String pillLabel;
    switch (status) {
      case 'ongoing':
        pillGrad = const [Color(0xFF22C55E), Color(0xFF10B981)]; // green → emerald
        pillLabel = 'Live';
        break;
      case 'completed':
        pillGrad = const [Color(0xFF6B7280), Color(0xFF475569)]; // gray → slate
        pillLabel = 'Done';
        break;
      default:
        pillGrad = const [Color(0xFFF59E0B), Color(0xFFFB923C)]; // amber → orange
        pillLabel = 'Soon';
    }

    final userRegistered = asBool(raw['user_registered']);
    final userSubmitted = asBool(raw['user_submitted']);
    final resultsPublished = asBool(
      raw['results_published'] ??
      raw['result_published'] ??
      raw['resultsPublished'] ??
      raw['has_results'] ??
      raw['hasResults']
    );
    final String? resultStatus = (() {
      final v = raw['user_result_status'] ?? raw['userResultStatus'];
      return (v == null) ? null : '$v'.trim();
    })();

    final totalRegs = asInt((raw['stats'] ?? const {})['totalRegistrations']);
    final maxTeam = asInt(raw['max_team_size'] ?? raw['maxTeamSize']);
    final seatsRemaining = raw['seats_remaining'];
    final totalSeats = raw['total_seats'] ?? raw['totalSeats'];
    final banner = raw['banner_image_url'] ?? raw['bannerImageUrl'];
    final posterName = raw['posted_by']?['name'] ?? raw['postedBy']?['name'] ?? 'Unknown';
    final id = c.id ?? '';

    // Role flags
    final auth = context.read<AuthProvider?>();
    final role = (auth?.user?.role ?? '').toLowerCase();
    final isAdmin = role == 'admin';
    final isHiring = role == 'hiring';
    final isInvestor = role == 'investor';
    final isStudent = role == 'student' || role == 'user';

    // student/user status chip for My Competitions
    Widget? myStatus;
    if (_active == CompFilter.myCompetitions) {
      if (userSubmitted) {
        myStatus = _statusChip('Submitted', const [Color(0xFF3B82F6), Color(0xFF38BDF8)]); // blue → sky
      } else if (userRegistered) {
        myStatus = _statusChip('Registered', const [Color(0xFF22C55E), Color(0xFF10B981)]);
      } else {
        myStatus = _statusChip('Participating', const [Color(0xFF8B5CF6), Color(0xFFA855F7)]);
      }
    }

    // action handlers
    Future<void> goRegister() async {
      final res = await context.push('/competition/${c.id}/register');
      if (res == true && id.isNotEmpty) {
        // optimistic set + persist
        setState(() {
          _optimisticRegistered.add(id);
        });
        await _saveSet(_LS_REG, _optimisticRegistered);
        // patch local card immediately
        final idx = _competitions.indexWhere((x) => x.id == id);
        if (idx != -1) {
          final updated = _competitions[idx];
          final newRaw = Map<String, dynamic>.from(updated.extra);
          newRaw['user_registered'] = true;
          _competitions[idx] = updated.copyWith(extra: newRaw);
        }
        _refresh();
      }
    }

    Future<void> goSubmit() async {
      final result = await context.push(
        '/competition/${c.id}/submit',
        extra: {
          'title': c.title,
          'meta': {
            'start_date': (c.startDate ?? asDate(raw['start_date']))?.toIso8601String(),
            'end_date': (c.endDate ?? asDate(raw['end_date']))?.toIso8601String(),
            if (seatsRemaining != null) 'seats_remaining': seatsRemaining,
          },
        },
      );
      if (result == true && id.isNotEmpty) {
        setState(() {
          _optimisticSubmitted.add(id);
          _optimisticRegistered.add(id);
        });
        await _saveSet(_LS_SUB, _optimisticSubmitted);
        await _saveSet(_LS_REG, _optimisticRegistered);
        final idx = _competitions.indexWhere((x) => x.id == id);
        if (idx != -1) {
          final updated = _competitions[idx];
          final newRaw = Map<String, dynamic>.from(updated.extra);
          newRaw['user_submitted'] = true;
          newRaw['user_registered'] = true;
          _competitions[idx] = updated.copyWith(extra: newRaw);
        }
        _refresh();
      }
    }

    Future<void> adminDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete competition?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      setState(() => _deletingId = id);
      try {
        await _apiService.deleteCompetition(id);
        await _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      } finally {
        if (mounted) setState(() => _deletingId = null);
      }
    }

    // card UI
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final res = await context.push('/competition/${c.id}');
          if (res is Map && res['refreshCompetitions'] == true) _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top row: banner + title + pill(s)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner — responsive without causing overflow
                  Container(
                    width: 96,
                    height: 96,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
                      color: theme.colorScheme.surfaceVariant.withOpacity(.35),
                    ),
                    child: (banner is String && banner.isNotEmpty)
                        ? Image.network(
                            banner,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.emoji_events_outlined, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : Center(child: Icon(Icons.emoji_events_outlined, color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 12),
                  // title + chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title + status pill + myStatus (wrap to avoid overflow)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 180, maxWidth: 600),
                              child: Text(
                                c.title,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _statusChip(pillLabel, pillGrad),
                                if (myStatus != null) ...[
                                  const SizedBox(width: 8),
                                  myStatus,
                                ]
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // date row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              '${fmtDate(c.startDate ?? asDate(raw['start_date']), withYear: false)} – ${fmtDate(c.endDate ?? asDate(raw['end_date']), withYear: false)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // description
                        Text(
                          c.description,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // tags
                        if (c.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final t in c.tags.take(3))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.tag, size: 13),
                                        const SizedBox(width: 4),
                                        Text(t, style: theme.textTheme.labelSmall),
                                      ],
                                    ),
                                  ),
                                if (c.tags.length > 3)
                                  Text(
                                    '+${c.tags.length - 3} more',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        // stats
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          children: [
                            _IconStat(icon: Icons.groups_2_outlined, label: '$totalRegs registered'),
                            if (seatsRemaining != null && totalSeats != null)
                              _IconStat(
                                  icon: Icons.format_list_numbered,
                                  label: '${seatsRemaining.toString()} / $totalSeats seats left'),
                            if (seatsRemaining != null && totalSeats == null)
                              _IconStat(icon: Icons.format_list_numbered, label: '${seatsRemaining.toString()} seats left'),
                            if (maxTeam > 0) _IconStat(icon: Icons.group_add_outlined, label: 'Max team: $maxTeam'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // bottom row: posted by + actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // posted by
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.person_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            posterName,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // actions (role-based)
                  Builder(builder: (context) {
                    if (isAdmin) {
                      if (status == 'upcoming') {
                        return Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'View submissions',
                              onPressed: () {
                                context.push('/admin/competition/${c.id}/submissions',
                                    extra: {'competitionId': c.id, 'competitionTitle': c.title});
                              },
                              icon: const Icon(Icons.remove_red_eye_outlined),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () async {
                                final res = await context.push('/competition/${c.id}/edit');
                                if (res is Map && res['refreshCompetitions'] == true) _refresh();
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: _deletingId == id ? null : adminDelete,
                              icon: _deletingId == id
                                  ? const SizedBox(
                                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.delete_outline, color: Colors.red),
                            ),
                          ],
                        );
                      } else if (status == 'ongoing') {
                        return IconButton(
                          tooltip: 'View submissions',
                          onPressed: () {
                            context.push('/admin/competition/${c.id}/submissions',
                                extra: {'competitionId': c.id, 'competitionTitle': c.title});
                          },
                          icon: const Icon(Icons.remove_red_eye_outlined),
                        );
                      } else {
                        // completed
                        return Wrap(
                          spacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => context.push('/competition/${c.id}/leaderboard'),
                              icon: const Icon(Icons.leaderboard_outlined),
                              label: const Text('View Results'),
                            ),
                            IconButton(
                              tooltip: 'View submissions',
                              onPressed: () {
                                context.push('/admin/competition/${c.id}/submissions',
                                    extra: {'competitionId': c.id, 'competitionTitle': c.title});
                              },
                              icon: const Icon(Icons.remove_red_eye_outlined),
                            ),
                          ],
                        );
                      }
                    }

                    if (isHiring || isInvestor) {
                      return Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: 'View details',
                            onPressed: () {
                              context.push('/competition/${c.id}/participants',
                                  extra: {'competitionId': c.id, 'title': c.title});
                            },
                            icon: const Icon(Icons.info_outline),
                          ),
                          IconButton(
                            tooltip: resultsPublished ? 'View results' : 'Results pending',
                            onPressed:
                                resultsPublished ? () => context.push('/competition/${c.id}/leaderboard') : null,
                            icon: Icon(Icons.leaderboard_outlined,
                                color: resultsPublished ? null : Theme.of(context).disabledColor),
                          ),
                        ],
                      );
                    }

                    // Student/User actions
                    if (status == 'upcoming') {
                      return userRegistered
                          ? _statusChip('Registered', const [Color(0xFF22C55E), Color(0xFF10B981)])
                          : FilledButton.icon(
                              onPressed: goRegister,
                              icon: const Icon(Icons.how_to_reg),
                              label: const Text('Register'),
                            );
                    }
                    if (status == 'ongoing') {
                      if (userSubmitted) {
                        return _statusChip('Submitted', const [Color(0xFF3B82F6), Color(0xFF38BDF8)]);
                      }
                      return userRegistered
                          ? OutlinedButton.icon(
                              onPressed: goSubmit,
                              icon: const Icon(Icons.upload_outlined),
                              label: const Text('Submit'),
                            )
                          : _statusChip('Not registered', const [Color(0xFFE11D48), Color(0xFFF43F5E)]);
                    }
                    // completed
                    if (!userRegistered) return const SizedBox.shrink();
                    if (!userSubmitted) {
                      return _statusChip('Not submitted', const [Color(0xFFD946EF), Color(0xFFA855F7)]);
                    }
                    if (!resultsPublished) {
                      return _statusChip('Waiting for results', const [Color(0xFFF59E0B), Color(0xFFFDE047)]);
                    }
                    // map result label
                    final rs = (resultStatus ?? '').toLowerCase();
                    List<Color> grad;
                    String label;
                    if (rs.contains('winner')) {
                      grad = const [Color(0xFFF59E0B), Color(0xFFF59E0B)]; label = 'Winner';
                    } else if (rs.contains('final')) {
                      grad = const [Color(0xFF8B5CF6), Color(0xFFA855F7)]; label = 'Finalist';
                    } else if (rs.contains('qualif')) {
                      grad = const [Color(0xFF10B981), Color(0xFF22C55E)]; label = 'Qualified';
                    } else if (rs.contains('disqual') || rs.contains('reject') || rs.contains('fail')) {
                      grad = const [Color(0xFFEF4444), Color(0xFFE11D48)]; label = 'Disqualified';
                    } else {
                      grad = const [Color(0xFF64748B), Color(0xFF475569)]; label = 'Result';
                    }

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statusChip(label, grad),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => context.push('/competition/${c.id}/leaderboard'),
                          child: const Text('View Results'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Competitions'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Competitions'), elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Failed to load competitions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade300)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadCompetitions, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final items = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Competitions'), elevation: 0),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ScrollConfiguration(
                behavior: _NoScrollbarBehavior(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _header(context);
                    final competition = items[index - 1];
                    return _buildCompetitionCard(competition);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------- small UI helpers -------------------
class _IconStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IconStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// only override extra to avoid type issues
extension _CopyWith on Competition {
  Competition copyWith({Map<String, dynamic>? extra}) {
    return Competition(
      id: id,
      title: title,
      description: description,
      descriptionLong: descriptionLong,
      startDate: startDate,
      endDate: endDate,
      registrationStartDate: registrationStartDate,
      registrationDeadline: registrationDeadline,
      entryDeadline: entryDeadline,
      teamMergerDeadline: teamMergerDeadline,
      finalSubmissionDeadline: finalSubmissionDeadline,
      resultsDate: resultsDate,
      bannerImageUrl: bannerImageUrl,
      prizePool: prizePool,
      maxTeamSize: maxTeamSize,
      rules: rules,
      rulesMarkdown: rulesMarkdown,
      sponsor: sponsor,
      location: location,
      tags: tags,
      resourcesJson: resourcesJson,
      prizesJson: prizesJson,
      stats: stats,
      extra: extra ?? this.extra,
    );
  }
}
