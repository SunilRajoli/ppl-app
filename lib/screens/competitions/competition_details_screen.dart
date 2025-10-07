import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/user_model.dart';
import '../../core/services/api_service.dart';

class CompetitionDetailsScreen extends StatefulWidget {
  final String competitionId;

  const CompetitionDetailsScreen({super.key, required this.competitionId});

  @override
  State<CompetitionDetailsScreen> createState() =>
      _CompetitionDetailsScreenState();
}

class _CompetitionDetailsScreenState extends State<CompetitionDetailsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;

  Competition? _comp;

  late TabController _tab;
  String _lbQuery = '';
  bool _lbLoading = false;
  String? _lbError;
  List<dynamic> _lbData = [];
  bool _lbFetched = false;
  Timer? _lbDebounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(_handleTabChange);
    _fetch();
  }

  @override
  void dispose() {
    _tab.removeListener(_handleTabChange);
    _tab.dispose();
    _lbDebounce?.cancel();
    super.dispose();
  }

  void _handleTabChange() {
    // Prevent multiple triggers during animation
    if (_tab.indexIsChanging) return;
    if (_tab.index == 1 && !_lbFetched) {
      _fetchLeaderboard();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getCompetition(widget.competitionId);
      if (!mounted) return;
      final raw = res is Map<String, dynamic> ? res : <String, dynamic>{};
      final data = (raw['data'] ?? raw) as Map<String, dynamic>;
      final compJson = (data['competition'] ?? data) as Map<String, dynamic>;

      setState(() {
        _comp = Competition.fromJson(compJson);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _lbLoading = true;
      _lbError = null;
      _lbFetched = true; // prevent refetch loops
    });
    try {
      final res = await _api.getCompetitionLeaderboard(widget.competitionId);
      if (!mounted) return;
      final raw = res is Map<String, dynamic> ? res : <String, dynamic>{};
      final data = (raw['data'] ?? raw) as Map<String, dynamic>;
      final rows = (data['leaderboard'] ?? data['rows'] ?? []) as List<dynamic>;
      setState(() {
        _lbData = rows;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lbError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _lbLoading = false;
      });
    }
  }

  String _fmtShort(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _fmtLong(DateTime? d) {
    if (d == null) return '—';
    return '${d.day} ${_monthName(d.month)} ${d.year}';
  }

  String _monthName(int m) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    final idx = (m - 1).clamp(0, 11);
    return months[idx];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Competition'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _comp == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Competition'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.rocket_launch,
                        color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(width: 12),
                  const Text('Couldn’t load', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                ),
                child: Text(
                  _error ?? 'Competition not found',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final c = _comp!;
    final tags = _safeList(c.extra?['tags']);
    final prizes = _safeList(c.extra?['prizes_json'] ?? c.stats?['prizes_json']);
    final resources = _safeList(c.extra?['resources_json'] ?? c.stats?['resources_json']);
    final contact = c.extra?['contact_info'] as Map<String, dynamic>?;
    final eligibility = c.extra?['eligibility_criteria'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Competition'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true, // horizontal scroll for tabs (as requested)
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Leaderboard'),
            Tab(text: 'Timeline'),
            Tab(text: 'Rules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ---------------------- OVERVIEW ----------------------
          RefreshIndicator(
            onRefresh: _fetch,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryHeader(c: c),
                  const SizedBox(height: 12),

                  _BadgeRow(
                    location: _stringOrNull(c.extra?['location'] ?? c.stats?['location']),
                    maxTeam: _intOrNull(c.extra?['max_team_size'] ?? c.stats?['max_team_size']),
                    prizePool: _numOrNull(c.extra?['prize_pool'] ?? c.stats?['prize_pool']),
                    tags: tags,
                  ),

                  const SizedBox(height: 12),

                  _DateTriplet(
                    start: c.startDate,
                    end: c.endDate,
                    seatsRemaining: _intOrNull(c.extra?['seats_remaining'] ?? c.stats?['seats_remaining']),
                    fmt: _fmtShort,
                  ),

                  const SizedBox(height: 16),

                  if (c.description.isNotEmpty ||
                      (c.extra?['description_long']?.toString().isNotEmpty ?? false) ||
                      (c.extra?['overview']?.toString().isNotEmpty ?? false))
                    _TitledBox(
                      title: 'Overview',
                      child: Text(
                        (c.extra?['description_long']?.toString() ??
                                c.extra?['overview']?.toString() ??
                                c.description)
                            .toString(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),

                  if (resources.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _TitledBox(
                      title: 'Resources',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: resources
                            .map((r) => _resourceRow(context, r))
                            .toList(),
                      ),
                    ),
                  ],

                  if (prizes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _TitledBox(
                      title: 'Prizes',
                      child: _PrizesTable(prizes: prizes),
                    ),
                  ],

                  if (contact != null || eligibility != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _TitledBox(
                            title: 'Contact',
                            child: _ContactInfo(contact: contact),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TitledBox(
                            title: 'Eligibility',
                            child: _EligibilityInfo(eligibility: eligibility),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ---------------------- LEADERBOARD ----------------------
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) {
                          _lbDebounce?.cancel();
                          _lbDebounce = Timer(const Duration(milliseconds: 220), () {
                            if (!mounted) return;
                            setState(() => _lbQuery = v);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_lbError != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Failed to load leaderboard',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: _lbLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _leaderboardBody(theme),
                ),
              ],
            ),
          ),

          // ---------------------- TIMELINE ----------------------
          Padding(
            padding: const EdgeInsets.all(16),
            child: _TimelineRail(
              items: _timelineItemsFromCompetition(c, _fmtLong),
            ),
          ),

          // ---------------------- RULES ----------------------
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _TitledBox(
              title: 'Rules',
              child: Text(
                (c.extra?['rules_markdown']?.toString() ??
                        c.rules ??
                        'No rules have been provided for this competition.')
                    .toString(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- helpers ---------------- */

  Widget _resourceRow(BuildContext context, dynamic r) {
    final theme = Theme.of(context);
    final label = (r is Map && r['label'] != null) ? r['label'].toString() : null;
    final url = (r is Map && r['url'] != null) ? r['url'].toString() : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.link, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: url == null
                ? Text(label ?? 'Resource', style: theme.textTheme.bodyMedium)
                : InkWell(
                    onTap: () async {
                      final uri = Uri.tryParse(url);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      label ?? url,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboardBody(ThemeData theme) {
    if (_lbData.isEmpty) {
      return Center(
        child: Text(
          'No leaderboard data available',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final q = _lbQuery.toLowerCase();
    final filtered = _lbQuery.isEmpty
        ? _lbData
        : _lbData.where((row) {
            final name = (row['team_name'] ??
                    (row['leader'] is Map ? row['leader']['name'] : '') ??
                    '')
                .toString()
                .toLowerCase();
            final rankStr = (row['rank'] ?? '').toString();
            return rankStr.contains(_lbQuery) || name.contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No results for “$_lbQuery”.', style: theme.textTheme.bodyMedium),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // keep horizontal scrolling
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Rank')),
            DataColumn(label: Text('Team/User')),
            DataColumn(label: Text('Score')),
            DataColumn(label: Text('Status')),
          ],
          rows: List<DataRow>.generate(
            filtered.length,
            (i) {
              final row = filtered[i] as Map<String, dynamic>;
              final rank = row['rank'] ?? (i + 1);
              final name = row['team_name'] ??
                  (row['leader'] is Map ? row['leader']['name'] : '—') ??
                  '—';
              final score = row['final_score'] ?? (row['score'] is num ? row['score'] : null);
              final status = row['status'] ?? 'submitted';
              return DataRow(cells: [
                DataCell(Text(rank.toString())),
                DataCell(Text(name.toString())),
                DataCell(Text(
                  score is num
                      ? (score is double ? score.toStringAsFixed(3) : score.toString())
                      : (score?.toString() ?? '—'),
                )),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.toString()),
                )),
              ]);
            },
          ),
        ),
      ),
    );
  }

  List<_TimelineItem> _timelineItemsFromCompetition(
      Competition c, String Function(DateTime?) fmtLong) {
    final items = <_TimelineItem>[];

    void add(String key, DateTime? date, String short, String long) {
      if (date == null) return;
      items.add(_TimelineItem(
        key: key,
        date: date,
        label: long.isNotEmpty ? long : short,
      ));
    }

    DateTime? _dt(dynamic v) {
      if (v is DateTime) return v;
      return null;
    }

    add('registration_start_date',
        _dt(c.extra?['registration_start_date'] ?? c.registrationStartDate),
        'Registration opens.',
        'Registration opens.');
    add('registration_deadline',
        _dt(c.extra?['registration_deadline'] ?? c.registrationDeadline),
        'Registration closes.',
        'Registration closes.');
    add('start_date', c.startDate, 'Start Date.', 'Start Date.');
    add('entry_deadline', _dt(c.extra?['entry_deadline']),
        'Entry Deadline.',
        'Entry Deadline. You must accept the competition rules before this date in order to compete.');
    add('team_merger_deadline', _dt(c.extra?['team_merger_deadline']),
        'Team Merger Deadline.',
        'Team Merger Deadline. This is the last day participants may join or merge teams.');
    add('final_submission_deadline', _dt(c.extra?['final_submission_deadline']),
        'Final Submission Deadline.',
        'Final Submission Deadline.');
    add('end_date', c.endDate, 'Competition Ends.', 'Competition Ends.');
    add('results_date', _dt(c.extra?['results_date'] ?? c.resultsDate),
        'Results Announced.', 'Results announced.');

    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  /* ------------ type guards / safe extractors ------------ */

  List<dynamic> _safeList(dynamic v) {
    if (v is List) return v;
    return const [];
  }

  String? _stringOrNull(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }

  int? _intOrNull(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  num? _numOrNull(dynamic v) {
    if (v is num) return v;
    return null;
  }
}

/* ===================== sub-widgets ===================== */

class _SummaryHeader extends StatelessWidget {
  final Competition c;
  const _SummaryHeader({required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: (c.bannerImageUrl != null)
                ? Image.network(
                    c.bannerImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image, size: 24),
                  )
                : const Icon(Icons.image, size: 24),
          ),
          const SizedBox(width: 12),
          // title, sponsor
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if ((c.extra?['sponsor']?.toString().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Sponsor: ${c.extra?['sponsor']}',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Competition details',
                        style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final String? location;
  final int? maxTeam;
  final num? prizePool;
  final List<dynamic> tags;

  const _BadgeRow({
    required this.location,
    required this.maxTeam,
    required this.prizePool,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    List<Widget> chips = [];
    if (location != null && location!.isNotEmpty) {
      chips.add(_chip(theme, Icons.location_on, location!));
    }
    if (maxTeam != null) {
      chips.add(_chip(theme, Icons.group, 'Max team: $maxTeam'));
    }
    if (prizePool != null) {
      chips.add(_chip(theme, Icons.card_giftcard, 'Prize pool: ₹$prizePool'));
    }
    if (tags.isNotEmpty) {
      chips.add(Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags
            .map((t) => _chip(theme, Icons.tag, t.toString(), dense: true))
            .toList(),
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label, {bool dense = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 16, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DateTriplet extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final int? seatsRemaining;
  final String Function(DateTime?) fmt;

  const _DateTriplet({
    required this.start,
    required this.end,
    required this.seatsRemaining,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget pill(IconData icon, String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: value),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: pill(Icons.event, 'Start', fmt(start))),
            const SizedBox(width: 8),
            Expanded(child: pill(Icons.event, 'End', fmt(end))),
          ],
        ),
        if (seatsRemaining != null) ...[
          const SizedBox(height: 8),
          pill(Icons.groups, 'Seats Left', seatsRemaining.toString()),
        ],
      ],
    );
  }
}

class _TitledBox extends StatelessWidget {
  final String title;
  final Widget child;

  const _TitledBox({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PrizesTable extends StatelessWidget {
  final List<dynamic> prizes;
  const _PrizesTable({required this.prizes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Place')),
            DataColumn(label: Text('Amount')),
          ],
          rows: prizes.map((p) {
            final place = (p is Map && p['place'] != null) ? p['place'].toString() : '—';
            final amount = (p is Map && p['amount'] != null) ? p['amount'].toString() : '—';
            return DataRow(cells: [
              DataCell(Text(place)),
              DataCell(Text('₹$amount')),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _ContactInfo extends StatelessWidget {
  final Map<String, dynamic>? contact;
  const _ContactInfo({required this.contact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (contact == null || contact!.isEmpty) {
      return Text('No contact information provided.', style: theme.textTheme.bodyMedium);
    }
    final email = contact!['email'];
    final phone = contact!['phone'];
    final website = contact!['website'];
    final discord = contact!['discord'];
    List<Widget> lines = [];
    if (email != null) lines.add(Text('Email: $email', style: theme.textTheme.bodyMedium));
    if (phone != null) lines.add(Text('Phone: $phone', style: theme.textTheme.bodyMedium));
    if (website != null) lines.add(Text('Website: $website', style: theme.textTheme.bodyMedium));
    if (discord != null) lines.add(Text('Discord: $discord', style: theme.textTheme.bodyMedium));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);
  }
}

class _EligibilityInfo extends StatelessWidget {
  final Map<String, dynamic>? eligibility;
  const _EligibilityInfo({required this.eligibility});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (eligibility == null || eligibility!.isEmpty) {
      return Text('No eligibility info provided.', style: theme.textTheme.bodyMedium);
    }
    final minAge = eligibility!['minAge'];
    final maxAge = eligibility!['maxAge'];
    final education = eligibility!['education'];
    final countries = eligibility!['countriesAllowed'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (minAge != null) Text('Min Age: $minAge', style: theme.textTheme.bodyMedium),
        if (maxAge != null) Text('Max Age: $maxAge', style: theme.textTheme.bodyMedium),
        if (education != null) Text('Education: $education', style: theme.textTheme.bodyMedium),
        if (countries is List && countries.isNotEmpty)
          Text('Countries Allowed: ${countries.join(', ')}',
              style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/* ===================== TIMELINE ===================== */

class _TimelineItem {
  final String key;
  final DateTime date;
  final String label;
  _TimelineItem({required this.key, required this.date, required this.label});
}

/// Draws a dot and a line **only between items** (no full-height line).
class _TimelineRail extends StatelessWidget {
  final List<_TimelineItem> items;
  const _TimelineRail({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Text('No timeline data available.', style: theme.textTheme.bodyMedium);
    }

    return Column(
      children: List.generate(items.length, (index) {
        final it = items[index];
        final isLast = index == items.length - 1;
        return _TimelineTile(
          date: it.date,
          label: it.label,
          isLast: isLast,
        );
      }),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final DateTime date;
  final String label;
  final bool isLast;

  const _TimelineTile({
    super.key,
    required this.date,
    required this.label,
    required this.isLast,
  });

  String _monthName(int m) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    final idx = (m - 1).clamp(0, 11);
    return months[idx];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Leading axis (dot + optional connector below)
    final leading = Column(
      children: [
        // Dot
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outline),
          ),
        ),
        // Connector (only if not last)
        if (!isLast)
          Expanded(
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: theme.colorScheme.outline.withOpacity(0.4),
            ),
          ),
      ],
    );

    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Axis gutter
            SizedBox(
              width: 24,
              child: Center(child: leading),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text:
                          '${date.day} ${_monthName(date.month)} ${date.year} — ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: label),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
