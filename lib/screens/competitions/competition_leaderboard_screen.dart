import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';

class CompetitionLeaderboardScreen extends StatefulWidget {
  final String competitionId;

  const CompetitionLeaderboardScreen({
    super.key,
    required this.competitionId,
  });

  @override
  State<CompetitionLeaderboardScreen> createState() =>
      _CompetitionLeaderboardScreenState();
}

class _CompetitionLeaderboardScreenState
    extends State<CompetitionLeaderboardScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _payload; // normalized response

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getCompetitionLeaderboard(widget.competitionId);
      if (!mounted) return;
      // normalize: accept {data:{leaderboard,...}} or flat {leaderboard,...}
      final raw = (res is Map<String, dynamic>) ? res : <String, dynamic>{};
      final data = (raw['data'] ?? raw) as Map<String, dynamic>;
      setState(() {
        _payload = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _leaderboard {
    final lb = _payload?['leaderboard'];
    return (lb is List) ? lb : const <dynamic>[];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.error.withOpacity(.35),
              ),
            ),
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
      );
    }

    final title = _payload?['competition']?['title']?.toString() ??
        'Competition Leaderboard';
    final sponsor = _payload?['competition']?['sponsor']?.toString();
    final totalEntries = _payload?['totalEntries'] as int? ?? _leaderboard.length;

    final topThree = _leaderboard.take(3).toList();
    final remaining = _leaderboard.skip(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(.25),
                            ),
                          ),
                          child: Icon(Icons.emoji_events_outlined,
                              color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  )),
                              Text('Competition Results & Leaderboard',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  )),
                              if (sponsor != null && sponsor.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Sponsored by $sponsor',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      )),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Submissions',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )),
                            Text('$totalEntries',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Top performers
              if (topThree.isNotEmpty) ...[
                Row(
                  children: [
                    Text('Top Performers',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 1: #1 centered
                if (topThree.length >= 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: _PodiumCard(
                          entry: topThree[0] as Map<String, dynamic>,
                          rank: 1,
                          tone: _Tone.gold,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),

                // Row 2: #2 and #3
                Row(
                  children: [
                    Expanded(
                      child: (topThree.length >= 2)
                          ? _PodiumCard(
                              entry: topThree[1] as Map<String, dynamic>,
                              rank: 2,
                              tone: _Tone.silver,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: (topThree.length >= 3)
                          ? _PodiumCard(
                              entry: topThree[2] as Map<String, dynamic>,
                              rank: 3,
                              tone: _Tone.bronze,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // Remaining rankings
              if (remaining.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.format_list_numbered,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('All Rankings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  children: List.generate(remaining.length, (i) {
                    final entry = remaining[i] as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ListCard(entry: entry, rank: i + 4),
                    );
                  }),
                ),
              ],

              // Empty state
              if (_leaderboard.isEmpty) ...[
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.military_tech_outlined,
                          size: 56, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 10),
                      Text('No Results Yet',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Results will be published after evaluation.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------- Cards & helpers --------------------- */

enum _Tone { gold, silver, bronze }

class _PodiumCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int rank;
  final _Tone tone;

  const _PodiumCard({
    required this.entry,
    required this.rank,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color border;
    Gradient grad;
    switch (tone) {
      case _Tone.gold:
        border = Colors.amber.shade400.withOpacity(.35);
        grad = LinearGradient(colors: [
          Colors.amber.shade400.withOpacity(.25),
          Colors.amber.shade700.withOpacity(.15),
        ]);
        break;
      case _Tone.silver:
        border = Colors.blueGrey.shade300.withOpacity(.35);
        grad = LinearGradient(colors: [
          Colors.blueGrey.shade300.withOpacity(.25),
          Colors.blueGrey.shade500.withOpacity(.15),
        ]);
        break;
      case _Tone.bronze:
        border = Colors.orange.shade400.withOpacity(.35);
        grad = LinearGradient(colors: [
          Colors.orange.shade500.withOpacity(.25),
          Colors.orange.shade700.withOpacity(.15),
        ]);
        break;
    }

    final leader = entry['leader'] as Map<String, dynamic>?;
    final avatar = leader?['profile_pic_url']?.toString();
    final name = (entry['team_name'] ??
            leader?['name'] ??
            '—')
        .toString();
    final title = entry['title']?.toString();
    final score = entry['final_score'];

    String emoji = rank == 1 ? '👑' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '';
    final scoreText = (score is num)
        ? (score is double ? score.toStringAsFixed(2) : score.toString())
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text('#$rank',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 8),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(.3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: (avatar != null && avatar.isNotEmpty)
                ? Image.network(avatar, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.person,
                        color: theme.colorScheme.onSurfaceVariant))
                : Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(.25),
              ),
            ),
            child: Column(
              children: [
                Text('Score',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                Text(scoreText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int rank;

  const _ListCard({
    required this.entry,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leader = entry['leader'] as Map<String, dynamic>?;
    final avatar = leader?['profile_pic_url']?.toString();
    final name =
        (entry['team_name'] ?? leader?['name'] ?? '—').toString();
    final title = entry['title']?.toString();
    final status = entry['status']?.toString();
    final college = leader?['college']?.toString();
    final score = entry['final_score'];

    final scoreText = (score is num)
        ? (score is double ? score.toStringAsFixed(2) : score.toString())
        : 'N/A';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(.25)),
      ),
      child: Row(
        children: [
          // Rank pill
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(.25)),
            ),
            child: Text('$rank',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
          ),
          const SizedBox(width: 10),

          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline.withOpacity(.25)),
            ),
            clipBehavior: Clip.antiAlias,
            child: (avatar != null && avatar.isNotEmpty)
                ? Image.network(avatar, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant))
                : Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  if ((status ?? '').toLowerCase() == 'winner')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.amber.withOpacity(.35)),
                      ),
                      child: Text('Winner',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                ]),
                if (title != null && title.isNotEmpty)
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                if (college != null && college.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(college,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Score',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              Text(scoreText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
