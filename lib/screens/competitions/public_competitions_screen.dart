// lib/screens/competitions/public_competitions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard for share
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_model.dart';
import '../../core/services/api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../widgets/custom_widgets.dart'; // StatusChip, etc.
import '../../widgets/global_top_bar.dart'; // <-- your exact top bar

class PublicCompetitionsScreen extends StatefulWidget {
  const PublicCompetitionsScreen({super.key});

  @override
  State<PublicCompetitionsScreen> createState() =>
      _PublicCompetitionsScreenState();
}

class _PublicCompetitionsScreenState extends State<PublicCompetitionsScreen> {
  final ApiService _api = ApiService();

  final TextEditingController _searchCtrl = TextEditingController();

  List<Competition> _all = [];
  bool _loading = true;
  String? _error;

  String _activeTab = 'upcoming'; // 'upcoming' | 'ongoing' | 'completed'
  String _search = '';

  // Details sheet
  bool _detailsOpen = false;
  Competition? _detailsComp;

  // Auth modal (register CTA if not signed-in)
  bool _authModalOpen = false;
  Competition? _selectedForRegister;

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.listCompetitions();
      final data = res['data'] ?? res;
      final list = (data['competitions'] as List? ?? [])
          .map((e) => Competition.fromJson(e))
          .toList();
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Compute status from dates; fallback to model status
  String _computeStatus(Competition c) {
    final start = c.startDate;
    final end = c.endDate;
    final now = DateTime.now();
    if (start != null && start.isAfter(now)) return 'upcoming';
    if (start != null && end != null && !start.isAfter(now) && end.isAfter(now)) {
      return 'ongoing';
    }
    if (end != null && end.isBefore(now)) return 'completed';
    return (c.status.isNotEmpty ? c.status : 'upcoming').toLowerCase();
  }

  List<Competition> get _filtered {
    final byTab = _all.where((c) => _computeStatus(c) == _activeTab).toList();
    if (_search.isEmpty) return byTab;
    final q = _search.toLowerCase();
    return byTab.where((c) {
      final t = c.title.toLowerCase();
      final d = (c.description).toLowerCase();
      return t.contains(q) || d.contains(q);
    }).toList();
  }

  String _heroTitle() {
    switch (_activeTab) {
      case 'ongoing':
        return 'Live Competitions';
      case 'completed':
        return 'Completed Competitions';
      default:
        return 'Explore Upcoming Competitions';
    }
  }

  String _heroSubtitle() {
    switch (_activeTab) {
      case 'ongoing':
        return "See what's live right now and follow along.";
      case 'completed':
        return 'Browse previous challenges and their results.';
      default:
        return 'Join challenges, collaborate with peers, and showcase your ideas to the world.';
    }
  }

  void _openDetails(Competition c) {
    setState(() {
      _detailsComp = c;
      _detailsOpen = true;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CompetitionDetailsSheet(
        competition: c,
        onClose: () => Navigator.of(context).pop(),
      ),
    ).whenComplete(() {
      setState(() {
        _detailsOpen = false;
        _detailsComp = null;
      });
    });
  }

  void _onRegisterTap(Competition c) {
    final auth = context.read<AuthProvider>();
    final isAuthed = auth.isAuthenticated;
    if (!isAuthed) {
      setState(() {
        _selectedForRegister = c;
        _authModalOpen = true;
      });
      showModalBottomSheet(
        context: context,
        barrierColor: Colors.black54,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _AuthRequiredSheet(
          competitionTitle: c.title,
          onCreate: () {
            Navigator.pop(context);
            context.push('/roles');
          },
          onLogin: () {
            Navigator.pop(context);
            context.push('/login');
          },
          onLater: () => Navigator.pop(context),
        ),
      ).whenComplete(() {
        setState(() {
          _authModalOpen = false;
          _selectedForRegister = null;
        });
      });
      return;
    }
    // Navigate to your competition detail/registration flow
    context.push('/competition/${c.id}');
  }

  // TopBar helpers
  List<NavLink> get _navLinks => const []; // mobile-only; content handled by GlobalTopBar
  bool get _isOnLanding => false;

  void _openContact() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4, width: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Text('Contact', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(labelText: 'Your Email', hintText: 'you@example.com'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(labelText: 'Message'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Send'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: GlobalTopBar(
        brand: 'PPL',
        navLinks: _navLinks,
        showRegister: !auth.isAuthenticated,
        isOnLanding: _isOnLanding,
        onScrollTo: null,
        onOpenContact: _openContact,
      ),

      // WHOLE SCREEN SCROLLABLE
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                scrollbars: false, // hide Flutter scrollbars on web/desktop
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- HERO ----------
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.65),
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor.withOpacity(0.6),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _heroTitle(),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _heroSubtitle(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.textTheme.titleMedium?.color?.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _TabPill(
                                label: 'Ongoing',
                                selected: _activeTab == 'ongoing',
                                onTap: () => setState(() => _activeTab = 'ongoing'),
                                icon: Icons.bolt_outlined,
                              ),
                              _TabPill(
                                label: 'Upcoming',
                                selected: _activeTab == 'upcoming',
                                onTap: () => setState(() => _activeTab = 'upcoming'),
                                icon: Icons.access_time,
                              ),
                              _TabPill(
                                label: 'Completed',
                                selected: _activeTab == 'completed',
                                onTap: () => setState(() => _activeTab = 'completed'),
                                icon: Icons.check_circle_outline,
                              ),
                            ],
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
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Failed to load competitions',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                                    ),
                                  ),
                                  TextButton(onPressed: _fetch, child: const Text('Retry')),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ---------- SEARCH ----------
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search ${_activeTab} competitions...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),

                    // ---------- LIST (composes into outer scroll) ----------
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _EmptyState(tab: _activeTab),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final c = _filtered[i];
                          final status = _computeStatus(c);
                          return _CompetitionCard(
                            competition: c,
                            status: status,
                            onTap: () => _openDetails(c),
                            onRegister: status == 'upcoming' ? () => _onRegisterTap(c) : null,
                          );
                        },
                      ),

                    // ---------- FOOTER ----------
                    const _FooterMini(),
                  ],
                ),
              ),
            ),
    );
  }
}

/* --------------------------- widgets --------------------------- */

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    final selBg = theme.colorScheme.surfaceVariant.withOpacity(0.6);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: selected
          ? base.merge(
              OutlinedButton.styleFrom(
                backgroundColor: selBg,
                foregroundColor: theme.colorScheme.onSurface,
              ),
            )
          : base,
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  final Competition competition;
  final String status; // upcoming|ongoing|completed
  final VoidCallback onTap;
  final VoidCallback? onRegister;

  const _CompetitionCard({
    required this.competition,
    required this.status,
    required this.onTap,
    this.onRegister,
  });

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    return '$day/$mon/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // banner
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: competition.bannerImageUrl != null
                        ? Image.network(
                            competition.bannerImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Icon(Icons.image)),
                          )
                        : const Center(child: Icon(Icons.emoji_events, size: 36)),
                  ),
                  const SizedBox(width: 12),
                  // title + status + dates
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                competition.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip(status: status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (competition.startDate != null || competition.endDate != null)
                          Text(
                            '${_fmt(competition.startDate)} – ${_fmt(competition.endDate)}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                competition.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.people, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${competition.stats?['totalRegistrations'] ?? 0} registered',
                      style: theme.textTheme.bodySmall,
                    ),
                  ]),
                  if (onRegister != null)
                    ElevatedButton(
                      onPressed: onRegister,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Register'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String tab;
  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    final msg = tab == 'upcoming'
        ? 'No upcoming competitions'
        : tab == 'ongoing'
            ? 'No live competitions'
            : 'No completed competitions';
    final sub = tab == 'upcoming'
        ? 'Check back later for new challenges'
        : tab == 'ongoing'
            ? 'No competitions are live right now'
            : 'Completed competitions will appear here';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 64),
            const SizedBox(height: 12),
            Text(msg, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text(sub, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/* ----------------------- Details Bottom Sheet (interactive + gray bg) ----------------------- */

class _CompetitionDetailsSheet extends StatefulWidget {
  final Competition competition;
  final VoidCallback onClose;

  const _CompetitionDetailsSheet({
    required this.competition,
    required this.onClose,
  });

  @override
  State<_CompetitionDetailsSheet> createState() =>
      _CompetitionDetailsSheetState();
}

class _CompetitionDetailsSheetState extends State<_CompetitionDetailsSheet> {
  // tabs: 0: overview, 1: leaderboard, 2: timeline, 3: rules
  final PageController _pageCtrl = PageController();
  int _tabIndex = 0;

  final _api = ApiService();
  bool _lbLoading = false;
  String? _lbError;
  List<dynamic> _leaderboard = const [];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  String _fmtShort(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _computeStatus(Competition c) {
    final start = c.startDate;
    final end = c.endDate;
    final now = DateTime.now();
    if (start != null && start.isAfter(now)) return 'upcoming';
    if (start != null && end != null && !start.isAfter(now) && end.isAfter(now)) return 'ongoing';
    if (end != null && end.isBefore(now)) return 'completed';
    return (c.status.isNotEmpty ? c.status : 'upcoming').toLowerCase();
  }

  Future<void> _loadLeaderboard({bool force = false}) async {
    if (_lbLoading || (_leaderboard.isNotEmpty && !force)) return;
    setState(() {
      _lbLoading = true;
      _lbError = null;
    });
    try {
      final res = await _api.getCompetitionLeaderboard(widget.competition.id);
      final data = res['data'] ?? res;
      final list = data['leaderboard'] ?? data['rows'] ?? data;
      setState(() {
        _leaderboard = (list is List) ? list : const [];
      });
    } catch (e) {
      setState(() => _lbError = e.toString());
    } finally {
      setState(() => _lbLoading = false);
    }
  }

  Future<void> _shareLink() async {
    final url = 'https://ppl.example.com/competition/${widget.competition.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.competition;
    final status = _computeStatus(c);
    final isUpcoming = status == 'upcoming';

    // Kick leaderboard load when user hits that tab
    if (_tabIndex == 1 && _leaderboard.isEmpty && !_lbLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLeaderboard());
    }

    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.95,
      initialChildSize: 0.88,
      minChildSize: 0.6,
      builder: (context, scrollCtrl) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // ===== Header =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: (c.bannerImageUrl != null)
                            ? Image.network(
                                c.bannerImageUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image, size: 24),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.emoji_events,
                                    color: theme.colorScheme.primary),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                StatusChip(status: status),
                                const SizedBox(width: 8),
                                if (c.startDate != null || c.endDate != null)
                                  Text(
                                    '${_fmtShort(c.startDate)} – ${_fmtShort(c.endDate)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // IconButton(
                      //   tooltip: 'Copy share link',
                      //   onPressed: _shareLink,
                      //   icon: const Icon(Icons.share),
                      // ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // ===== Tab pills =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _DetailTabBtn(
                        label: 'Overview',
                        selected: _tabIndex == 0,
                        onTap: () {
                          setState(() => _tabIndex = 0);
                          _pageCtrl.animateToPage(0,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOut);
                        },
                      ),
                      _DetailTabBtn(
                        label: 'Leaderboard',
                        selected: _tabIndex == 1,
                        onTap: () {
                          setState(() => _tabIndex = 1);
                          _pageCtrl.animateToPage(1,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOut);
                        },
                      ),
                      _DetailTabBtn(
                        label: 'Timeline',
                        selected: _tabIndex == 2,
                        onTap: () {
                          setState(() => _tabIndex = 2);
                          _pageCtrl.animateToPage(2,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOut);
                        },
                      ),
                      _DetailTabBtn(
                        label: 'Rules',
                        selected: _tabIndex == 3,
                        onTap: () {
                          setState(() => _tabIndex = 3);
                          _pageCtrl.animateToPage(3,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOut);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ===== Pages (swipe horizontally) with gray background =====
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(
                      Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.5,
                    ),
                    child: ScrollConfiguration(
                      behavior: const MaterialScrollBehavior().copyWith(
                        scrollbars: false, // hide internal scrollbars
                      ),
                      child: PageView(
                        controller: _pageCtrl,
                        onPageChanged: (i) => setState(() => _tabIndex = i),
                        children: [
                          // ---- OVERVIEW ----
                          SingleChildScrollView(
                            controller: scrollCtrl,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (c.description.isNotEmpty) ...[
                                    Text('Overview',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        )),
                                    const SizedBox(height: 6),
                                    Text(c.description, style: theme.textTheme.bodyMedium),
                                    const SizedBox(height: 14),
                                  ],
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _InfoTile(
                                          title: 'Start',
                                          value: _fmtShort(c.startDate),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _InfoTile(
                                          title: 'End',
                                          value: _fmtShort(c.endDate),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((c.stats?['maxTeamSize']) != null) ...[
                                    const SizedBox(height: 12),
                                    _InfoTile(
                                      title: 'Team Size',
                                      value:
                                          'Maximum ${c.stats?['maxTeamSize']} members per team.',
                                    ),
                                  ],
                                  if ((c.stats?['prizePool']) != null) ...[
                                    const SizedBox(height: 12),
                                    _InfoTile(
                                      title: 'Prize Pool',
                                      value: '₹${c.stats?['prizePool']}',
                                      big: true,
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  if (isUpcoming)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.rocket_launch),
                                        onPressed: () {
                                          Navigator.pop(context); // close sheet
                                          GoRouter.of(context).push('/competition/${c.id}');
                                        },
                                        label: const Text('Register Now'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // ---- LEADERBOARD ----
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ScrollConfiguration(
                                behavior: const MaterialScrollBehavior().copyWith(
                                  scrollbars: false,
                                ),
                                child: RefreshIndicator(
                                  onRefresh: () async => _loadLeaderboard(force: true),
                                  child: _LeaderboardView(
                                    loading: _lbLoading,
                                    error: _lbError,
                                    entries: _leaderboard,
                                    scrollableList: true,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ---- TIMELINE ----
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: SingleChildScrollScrollViewWithToday(
                                controller: scrollCtrl,
                                competition: c,
                              ),
                            ),
                          ),

                          // ---- RULES ----
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: SingleChildScrollView(
                                controller: scrollCtrl,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  (c.rules?.isNotEmpty == true)
                                      ? c.rules!
                                      : 'No rules have been provided for this competition.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Timeline page helper with a "Today" marker when applicable
class SingleChildScrollScrollViewWithToday extends StatelessWidget {
  final ScrollController controller;
  final Competition competition;
  const SingleChildScrollScrollViewWithToday({
    super.key,
    required this.controller,
    required this.competition,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String, DateTime)>[
      if (competition.registrationStartDate != null)
        ('Registration Opens', competition.registrationStartDate!),
      if (competition.registrationDeadline != null)
        ('Entry Deadline', competition.registrationDeadline!),
      if (competition.startDate != null) ('Start Date', competition.startDate!),
      if (competition.endDate != null)
        ('Final Submission Deadline', competition.endDate!),
      if (competition.resultsDate != null)
        ('Results Announced', competition.resultsDate!),
    ];

    if (items.isNotEmpty) {
      final now = DateTime.now();
      final minD = items.map((e) => e.$2).reduce((a, b) => a.isBefore(b) ? a : b);
      final maxD = items.map((e) => e.$2).reduce((a, b) => a.isAfter(b) ? a : b);
      if (!now.isBefore(minD) && !now.isAfter(maxD)) {
        items.add(('Today', now));
      }
    }

    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      child: SingleChildScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: _TimelineList(items: items),
      ),
    );
  }
}

// Upgraded leaderboard (works with RefreshIndicator)
class _LeaderboardView extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<dynamic> entries;
  final bool scrollableList;

  const _LeaderboardView({
    required this.loading,
    required this.error,
    required this.entries,
    this.scrollableList = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, __) => Container(
          height: 52,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: 6,
      );
    }

    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load leaderboard',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('No leaderboard data yet.', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    String nameOf(dynamic row) {
      if (row is Map) {
        return (row['team']?['name'] ??
                row['user']?['name'] ??
                row['name'] ??
                row['teamName'] ??
                row['username'] ??
                '—')
            .toString();
      }
      return row.toString();
    }

    String scoreOf(dynamic row) {
      if (row is Map) {
        final s = row['score'] ?? row['points'] ?? row['rating'];
        return (s == null) ? '—' : s.toString();
      }
      return '—';
    }

    String rankOf(dynamic row, int index) {
      if (row is Map && row['rank'] != null) return row['rank'].toString();
      return '${index + 1}';
    }

    final listView = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final row = entries[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 14, child: Text(rankOf(row, i))),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nameOf(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Text(scoreOf(row), style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      },
    );

    return scrollableList
        ? listView
        : SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: SizedBox(height: 400, child: listView),
          );
  }
}

class _DetailTabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DetailTabBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final selectedFg = isDark ? Colors.white : Colors.black87;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: selectedBg,
      labelStyle: selected
          ? theme.textTheme.bodyMedium?.copyWith(color: selectedFg)
          : theme.textTheme.bodyMedium,
      pressElevation: 1,
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.4)),
    );
  }
}

// ---------------- Info tile (small labeled box) ----------------
class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final bool big;
  const _InfoTile({required this.title, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.textTheme.bodySmall?.color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: big
                ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------- Timeline list (vertical line + dots) ----------------
class _TimelineList extends StatelessWidget {
  final List<(String, DateTime)> items;
  const _TimelineList({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Text('No timeline data available.', style: theme.textTheme.bodyMedium);
    }

    final sorted = [...items]..sort((a, b) => a.$2.compareTo(b.$2));
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 0,
          bottom: 0,
          child: Container(width: 1, color: theme.colorScheme.outline.withOpacity(0.4)),
        ),
        Column(
          children: sorted.map((it) {
            final isToday = it.$1.toLowerCase() == 'today';
            final dotColor = isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface;
            final labelStyle = isToday
                ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                : theme.textTheme.bodyMedium;

            return Padding(
              padding: const EdgeInsets.only(left: 0, bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: '${fmt(it.$2)} — ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: it.$1, style: labelStyle),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/* ---------------------------- Footer (compact) ---------------------------- */

class _FooterMini extends StatelessWidget {
  const _FooterMini();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.dividerColor;
    final year = DateTime.now().year;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Premier Project League',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Turning student projects into real startups.',
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _FooterLink(label: 'Home', onTap: () => GoRouter.of(context).go('/')),
              _FooterLink(label: 'Competitions', onTap: () => GoRouter.of(context).go('/competitions')),
              _FooterLink(label: 'Login', onTap: () => GoRouter.of(context).go('/login')),
              _FooterLink(label: 'Sign up', onTap: () => GoRouter.of(context).go('/register')),
              _FooterLink(label: 'Terms', onTap: () => GoRouter.of(context).go('/terms')),
              _FooterLink(label: 'Privacy', onTap: () => GoRouter.of(context).go('/privacy')),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: divider),
          const SizedBox(height: 12),

          Text(
            '© $year Premier Project League',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.95),
          decoration: TextDecoration.underline,
          decorationColor: Colors.transparent,
        ),
      ),
    );
  }
}

/* ----------------------- Auth Required Sheet ----------------------- */

class _AuthRequiredSheet extends StatelessWidget {
  final String competitionTitle;
  final VoidCallback onCreate;
  final VoidCallback onLogin;
  final VoidCallback onLater;

  const _AuthRequiredSheet({
    required this.competitionTitle,
    required this.onCreate,
    required this.onLogin,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sign In Required',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.rocket_launch, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text('To register for', style: theme.textTheme.bodyMedium),
            Text(
              competitionTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Create an account or sign in to participate.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCreate,
                    child: const Text('Create Account'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onLogin,
                    child: const Text('I already have an account'),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: onLater,
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    );
  }
}
