// lib/screens/competitions/competitions_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_model.dart';
import '../../core/services/api_service.dart';
import '../../core/providers/auth_provider.dart';

// ------- tiny safe-parsing helpers -------
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

String fmtDate(DateTime? d, {bool withYear = true}) {
  if (d == null) return '—';
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return withYear ? '$dd/$mm/${d.year}' : '$dd/$mm';
}

// ------- filters -------
enum CompFilter { all, ongoing, upcoming, completed, myCompetitions }

// ------- hide scrollbar behavior -------
class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // no scrollbar widget
  }
}

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<Competition> _competitions = [];
  bool _isLoading = true;
  String? _error;

  bool _refreshing = false;
  CompFilter _active = CompFilter.all;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  int _cntOngoing = 0;
  int _cntUpcoming = 0;
  int _cntCompleted = 0;
  int _cntMine = 0; // my competitions (registered/submitted) for student
  bool _adminMyOnly = false; // admin-only toggle: only comps created by me

  // per-card loading states
  final Set<String> _busyRegister = <String>{};
  String? _deletingId;

  // ✅ optimistic flags
  final Set<String> _optimisticRegistered = <String>{};
  final Set<String> _optimisticSubmitted = <String>{};

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
    _loadCompetitions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _anim.dispose();
    super.dispose();
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
      var competitions = (data['competitions'] as List?)
              ?.map((e) => Competition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <Competition>[];

      // merge optimistic flags
      competitions = competitions.map((c) {
        final cid = (c.id ?? '').toString();
        final raw = Map<String, dynamic>.from(c.extra);
        raw['user_registered'] =
            asBool(raw['user_registered']) || _optimisticRegistered.contains(cid);
        raw['user_submitted'] =
            asBool(raw['user_submitted']) || _optimisticSubmitted.contains(cid);
        return c.copyWith(extra: raw);
      }).toList();

      int ongoing = 0, upcoming = 0, completed = 0, mine = 0;
      for (final c in competitions) {
        final s = c.status;
        if (s == 'ongoing') ongoing++;
        else if (s == 'upcoming') upcoming++;
        else if (s == 'completed') completed++;

        final raw = c.extra;
        if (asBool(raw['user_registered']) || asBool(raw['user_submitted'])) {
          mine++;
        }
      }

      if (!mounted) return;
      setState(() {
        _competitions = competitions;
        _cntOngoing = ongoing;
        _cntUpcoming = upcoming;
        _cntCompleted = completed;
        _cntMine = mine;
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

  bool _isPostedByMe(Competition c, User? me) {
    if (me == null) return false;
    final raw = c.extra;
    final postedBy = raw['posted_by'] ?? raw['postedBy'];
    final pid = (postedBy is Map) ? (postedBy['id'] ?? postedBy['_id']) : null;
    final myId = me.id;
    return (pid?.toString() ?? '') == (myId ?? '').toString();
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
        list = list.where((c) => c.status == 'ongoing');
        break;
      case CompFilter.upcoming:
        list = list.where((c) => c.status == 'upcoming');
        break;
      case CompFilter.completed:
        list = list.where((c) => c.status == 'completed');
        break;
      case CompFilter.myCompetitions:
        list = list.where((c) {
          final raw = c.extra;
          return asBool(raw['user_registered']) || asBool(raw['user_submitted']);
        });
        break;
      case CompFilter.all:
        break;
    }

    if (isAdmin && _adminMyOnly) {
      list = list.where((c) => _isPostedByMe(c, me));
    }

    // Hiring/Investor: ignore MyCompetitions filter
    if ((isHiring || isInvestor) && _active == CompFilter.myCompetitions) {
      list = _competitions;
    }

    if (q.isNotEmpty) {
      list = list.where((c) {
        final raw = c.extra;
        final sponsor = (raw['sponsor'] ?? '').toString().toLowerCase();
        final tags = c.tags.map((e) => e.toLowerCase());
        return c.title.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q) ||
            sponsor.contains(q) ||
            tags.any((t) => t.contains(q));
      });
    }
    return List<Competition>.from(list);
  }

  // ---- CARD ----
  Widget _buildCompetitionCard(Competition competition) {
    final theme = Theme.of(context);
    final raw = competition.extra;

    final status = competition.status;
    Color pillBg, pillText, pillBorder;
    String pillLabel;
    switch (status) {
      case 'ongoing':
        pillBg = Colors.green.withOpacity(.12);
        pillText = Colors.green.shade400;
        pillBorder = Colors.green.withOpacity(.25);
        pillLabel = 'Live';
        break;
      case 'completed':
        pillBg = Colors.grey.withOpacity(.12);
        pillText = Colors.grey.shade300;
        pillBorder = Colors.grey.withOpacity(.25);
        pillLabel = 'Done';
        break;
      default:
        pillBg = Colors.amber.withOpacity(.12);
        pillText = Colors.amber.shade300;
        pillBorder = Colors.amber.withOpacity(.25);
        pillLabel = 'Soon';
    }

    final userRegistered = asBool(raw['user_registered']);
    final userSubmitted = asBool(raw['user_submitted']);
    final totalRegs = asInt((raw['stats'] ?? const {})['totalRegistrations']);
    final maxTeam = asInt(raw['max_team_size'] ?? raw['maxTeamSize']);
    final seatsRemaining = raw['seats_remaining'];
    final totalSeats = raw['total_seats'] ?? raw['totalSeats'];
    final banner = raw['banner_image_url'] ?? raw['bannerImageUrl'];
    final posterName =
        raw['posted_by']?['name'] ?? raw['postedBy']?['name'] ?? 'Unknown';

    final tags = competition.tags;

    final auth = context.read<AuthProvider?>();
    final role = (auth?.user?.role ?? '').toLowerCase();
    final isAdmin = role == 'admin';
    final isHiring = role == 'hiring';
    final isInvestor = role == 'investor';
    final isStudent = role == 'student' || role == 'user';

    final id = competition.id ?? '';
    final isRegisterBusy = id.isNotEmpty && _busyRegister.contains(id);
    final isDeleting = _deletingId == id;

    // results flags
    final bool resultsPublished = asBool(
      raw['results_published'] ??
      raw['resultsPublished'] ??
      raw['has_results'] ??
      raw['hasResults']
    );
    final String? resultStatus = (() {
      final v = raw['result_status'] ?? raw['resultStatus'];
      return (v == null) ? null : '$v'.trim();
    })();

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
          // details page could also ask to refresh when popping (safe to handle)
          final res = await context.push('/competition/${competition.id}');
          if (res is Map && res['refreshCompetitions'] == true) {
            _refresh();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: banner + title + pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
                      image: (banner is String && banner.isNotEmpty)
                          ? DecorationImage(image: NetworkImage(banner), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (banner is String && banner.isNotEmpty)
                        ? null
                        : Icon(Icons.emoji_events_outlined, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                competition.title,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: pillBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: pillBorder),
                              ),
                              child: Text(
                                pillLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: pillText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          competition.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final t in tags.take(3))
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
                                if (tags.length > 3)
                                  Text('+${tags.length - 3} more',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      )),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              '${fmtDate(competition.startDate, withYear: false)} – ${fmtDate(competition.endDate, withYear: false)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          children: [
                            _IconStat(icon: Icons.groups_2_outlined, label: '$totalRegs registered'),
                            if (seatsRemaining != null && totalSeats != null)
                              _IconStat(icon: Icons.format_list_numbered, label: '${seatsRemaining.toString()} / $totalSeats seats left'),
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

              // Bottom row: posted by + actions/state
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right side actions per role + status
                  if (isAdmin) ...[
                    if (status == 'upcoming') ...[
                      // Upcoming: View details + Edit + Delete
                      IconButton(
                        tooltip: 'View details',
                        onPressed: () async {
                          final res = await context.push(
                            '/competition/${competition.id}/participants',
                            extra: {'competitionId': competition.id, 'title': competition.title},
                          );
                          if (res is Map && res['refreshCompetitions'] == true) _refresh();
                        },
                        icon: const Icon(Icons.info_outline),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () async {
                          final res = await context.push('/competition/${competition.id}/edit');
                          if (res is Map && res['refreshCompetitions'] == true) _refresh();
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: isDeleting
                            ? null
                            : () async {
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Delete failed: $e')),
                                  );
                                } finally {
                                  if (mounted) setState(() => _deletingId = null);
                                }
                              },
                        icon: isDeleting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ] else if (status == 'ongoing') ...[
                      // Ongoing: NO edit/delete → View details (who registered/submitted)
                      IconButton(
                        tooltip: 'View details',
                        onPressed: () async {
                          final res = await context.push(
                            '/competition/${competition.id}/participants',
                            extra: {'competitionId': competition.id, 'title': competition.title},
                          );
                          if (res is Map && res['refreshCompetitions'] == true) _refresh();
                        },
                        icon: const Icon(Icons.info_outline),
                      ),
                      IconButton(
                        tooltip: 'View submissions',
                        onPressed: () async {
                          final res = await context.push(
                            '/admin/competition/${competition.id}/submissions',
                            extra: {'competitionId': competition.id, 'competitionTitle': competition.title},
                          );
                          if (res is Map && res['refreshCompetitions'] == true) _refresh();
                        },
                        icon: const Icon(Icons.remove_red_eye_outlined),
                      ),
                    ] else ...[
                      // Completed: NO edit/delete → View results
                      IconButton(
                        tooltip: 'View results',
                        onPressed: () => context.push('/competition/${competition.id}/leaderboard'),
                        icon: const Icon(Icons.leaderboard_outlined),
                      ),
                    ],
                  ] else if (isHiring || isInvestor) ...[
                    // Hiring/Investor always: View details; for completed → View results if published
                    IconButton(
                      tooltip: 'View details',
                      onPressed: () async {
                        final res = await context.push(
                          '/competition/${competition.id}/participants',
                          extra: {'competitionId': competition.id, 'title': competition.title},
                        );
                        if (res is Map && res['refreshCompetitions'] == true) _refresh();
                      },
                      icon: const Icon(Icons.info_outline),
                    ),
                    IconButton(
                      tooltip: resultsPublished ? 'View results' : 'Results pending',
                      onPressed: resultsPublished
                          ? () => context.push('/competition/${competition.id}/leaderboard')
                          : null,
                      icon: Icon(
                        Icons.leaderboard_outlined,
                        color: resultsPublished ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                  ] else ...[
                    // Student/User: show status pill on "My Competitions" filter
                    if (_active == CompFilter.myCompetitions)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: userSubmitted ? Colors.blue.withOpacity(.12) : Colors.green.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (userSubmitted ? Colors.blue : Colors.green).withOpacity(.25),
                          ),
                        ),
                        child: Text(
                          userSubmitted ? 'Submitted' : 'Registered',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: userSubmitted ? Colors.blue.shade300 : Colors.green.shade400,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ],
              ),

              // Student/User only: register/submit/status bar
              if (isStudent) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Builder(builder: (context) {
                      switch (status) {
                        case 'ongoing':
                          if (userRegistered) {
                            return Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await context.push(
                                    '/competition/${competition.id}/submit',
                                    extra: {
                                      'title': competition.title,
                                      'meta': {
                                        'start_date': competition.startDate?.toIso8601String(),
                                        'end_date': competition.endDate?.toIso8601String(),
                                        if (seatsRemaining != null) 'seats_remaining': seatsRemaining,
                                      },
                                    },
                                  );
                                  if (result == true && competition.id != null) {
                                    setState(() {
                                      _optimisticSubmitted.add(competition.id!);
                                      final idx = _competitions.indexWhere((c) => c.id == competition.id);
                                      if (idx != -1) {
                                        final updated = _competitions[idx];
                                        final newRaw = Map<String, dynamic>.from(updated.extra);
                                        newRaw['user_submitted'] = true;
                                        newRaw['user_registered'] = true;
                                        _competitions[idx] = updated.copyWith(extra: newRaw);
                                        _cntMine = _competitions.where((c) =>
                                            asBool(c.extra['user_registered']) || asBool(c.extra['user_submitted'])).length;
                                      }
                                    });
                                    _refresh();
                                  }
                                },
                                icon: const Icon(Icons.upload_outlined),
                                label: const Text('Submit'),
                              ),
                            );
                          }
                          return Expanded(child: _statusChip(context, 'Not registered', Colors.orange));

                        case 'upcoming':
                          if (userRegistered) {
                            return Expanded(child: _statusChip(context, 'Registered', Colors.green));
                          }
                          return Expanded(
                            child: FilledButton.icon(
                              onPressed: isRegisterBusy
                                  ? null
                                  : () async {
                                      final result = await context.push('/competition/${competition.id}/register');
                                      if (result == true && competition.id != null) {
                                        setState(() {
                                          _optimisticRegistered.add(competition.id!);
                                          final idx = _competitions.indexWhere((c) => c.id == competition.id);
                                          if (idx != -1) {
                                            final updated = _competitions[idx];
                                            final newRaw = Map<String, dynamic>.from(updated.extra);
                                            newRaw['user_registered'] = true;
                                            _competitions[idx] = updated.copyWith(extra: newRaw);
                                            _cntMine = _competitions.where((c) =>
                                                asBool(c.extra['user_registered']) ||
                                                asBool(c.extra['user_submitted'])).length;
                                          }
                                        });
                                        _refresh();
                                      }
                                    },
                              icon: const Icon(Icons.how_to_reg),
                              label: const Text('Register'),
                            ),
                          );

                        case 'completed':
                        default:
                          if (userRegistered && !userSubmitted) {
                            return Expanded(child: _statusChip(context, 'Not submitted', Colors.orange));
                          }
                          if (userRegistered && userSubmitted) {
                            if (!resultsPublished) {
                              return Expanded(child: _statusChip(context, 'Waiting for results', Colors.blue));
                            }

                            final label = (resultStatus == null || resultStatus.isEmpty)
                                ? 'Submitted'
                                : resultStatus[0].toUpperCase() + resultStatus.substring(1);
                            final lc = (resultStatus ?? '').toLowerCase();
                            final color = lc.contains('qualif') || lc.contains('win')
                                ? Colors.green
                                : lc.contains('disqual') || lc.contains('fail') || lc.contains('reject')
                                    ? Colors.red
                                    : Colors.blueGrey;

                            return Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _statusChip(context, label, color)),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () => context.push('/competition/${competition.id}/leaderboard'),
                                    child: const Text('View Results'),
                                  ),
                                ],
                              ),
                            );
                          }
                          // Not registered → show nothing
                          return const Expanded(child: SizedBox.shrink());
                      }
                    }),
                  ],
                ),
              ],

              // Hiring/Investor quick results button (completed)
              if ((isHiring || isInvestor) && status == 'completed') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: resultsPublished
                      ? () => context.push('/competition/${competition.id}/leaderboard')
                      : null,
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: Text(resultsPublished ? 'View Results' : 'Results pending'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String label, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color.computeLuminance() > .5 ? Colors.black87 : color.withOpacity(.85),
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _metricButton({
    required String label,
    required int count,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData icon = Icons.insights_outlined,
  }) {
    final theme = Theme.of(context);
    final bg = color.withOpacity(.12);
    final ring = color.withOpacity(.30);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.outline.withOpacity(0.4) : theme.colorScheme.outline.withOpacity(0.25),
          ),
          boxShadow: selected
              ? [BoxShadow(color: ring, blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 12, backgroundColor: bg, child: Icon(icon, size: 14, color: color)),
            const SizedBox(width: 8),
            Text('$count', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
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
                    Text(
                      'Discover and join exciting competitions',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                FilledButton.icon(
                  onPressed: () async {
                    final res = await context.push('/competition/create');
                    if (res is Map && res['refreshCompetitions'] == true) {
                      _refresh();
                    }
                  },
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Create'),
                ),
            ],
          ),
        ),

        // Admin "My Competitions" toggle (created by me)
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

        // Metrics
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricButton(
              label: 'Ongoing',
              count: _cntOngoing,
              selected: _active == CompFilter.ongoing,
              color: Colors.green,
              onTap: () => setState(() => _active = CompFilter.ongoing),
              icon: Icons.show_chart,
            ),
            _metricButton(
              label: 'Upcoming',
              count: _cntUpcoming,
              selected: _active == CompFilter.upcoming,
              color: Colors.amber,
              onTap: () => setState(() => _active = CompFilter.upcoming),
              icon: Icons.schedule_outlined,
            ),
            _metricButton(
              label: 'Completed',
              count: _cntCompleted,
              selected: _active == CompFilter.completed,
              color: Colors.grey,
              onTap: () => setState(() => _active = CompFilter.completed),
              icon: Icons.check_circle_outline,
            ),
            if (isStudent)
              _metricButton(
                label: 'My Competitions',
                count: _cntMine,
                selected: _active == CompFilter.myCompetitions,
                color: Colors.blue,
                onTap: () => setState(() => _active = CompFilter.myCompetitions),
                icon: Icons.star_border,
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
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search competitions, sponsors, tags...',
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
    );
  }

  int _cntCreatedByMe(User? me) {
    if (me == null) return 0;
    return _competitions.where((c) => _isPostedByMe(c, me)).length;
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

/* ------------------- small UI helpers ------------------- */

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
