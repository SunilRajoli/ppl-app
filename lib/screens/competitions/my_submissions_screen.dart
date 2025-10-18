// lib/screens/competitions/my_submissions_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';

T? _pick<T>(Map? o, List<String> keys) {
  if (o == null) return null;
  for (final k in keys) {
    if (o.containsKey(k) && o[k] != null) return o[k] as T;
  }
  return null;
}

String _getVideoId(Map s) =>
    (s['video_id'] ?? s['videoId'])?.toString() ??
    _pick(s['video'] as Map?, ['id', 'video_id'])?.toString() ??
    '';

String _getPrimaryId(Map s) =>
    (s['id'] ?? s['_id'] ?? s['submission_id'] ?? s['submissionId'])?.toString() ?? '';

dynamic _getTs(Map s) =>
    (s['updated_at'] ?? s['updatedAt'] ?? s['created_at'] ?? s['createdAt']) ?? 0;

String _sid(Map s) {
  final pid = _getPrimaryId(s);
  if (pid.isNotEmpty) return pid;
  final t = ((s['title'] ?? s['project_title'] ?? '') as String);
  final d = _getTs(s).toString();
  final sm = ((s['summary'] ?? '') as String);
  return '${t.substring(0, t.length.clamp(0, 50))}|${sm.substring(0, sm.length.clamp(0, 10))}|$d';
}

List<Map<String, dynamic>> _dedupeKeepNewest(List list) {
  final map = <String, Map<String, dynamic>>{};
  for (final e in list) {
    final s = Map<String, dynamic>.from(e as Map);
    final sid = _sid(s);
    if (!map.containsKey(sid)) {
      map[sid] = s;
    } else {
      final a = DateTime.tryParse('${_getTs(map[sid]!).toString()}')?.millisecondsSinceEpoch ?? 0;
      final b = DateTime.tryParse('${_getTs(s).toString()}')?.millisecondsSinceEpoch ?? 0;
      map[sid] = (b >= a) ? s : map[sid]!;
    }
  }
  return map.values
      .map((x) => {
            ...x,
            'id': _getPrimaryId(x).isNotEmpty ? _getPrimaryId(x) : (x['id'] ?? x['_id']),
          })
      .toList();
}

String _statusText(dynamic v) {
  final s = (v?.toString() ?? '').trim();
  return s.isEmpty ? '—' : s.replaceAll('_', ' ');
}

// NOTE: removed "published" (handled by the Publish button).
const _STATUS_OPTIONS = <String>[
  'submitted',
  'under_review',
  'needs_changes',
  'shortlisted',
  'winner',
  'not_winner',
  'disqualified',
];

class MySubmissionsScreen extends StatefulWidget {
  final String? competitionId; // if present → admin/hiring/investor context
  final String? competitionTitle;

  const MySubmissionsScreen({super.key, this.competitionId, this.competitionTitle});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;

  // role
  late final String _role;
  bool get _isAdmin => _role == 'admin';
  bool get _isHiringOrInvestor => _role == 'hiring' || _role == 'investor';
  bool get _isAdminContext => widget.competitionId != null && (_isAdmin || _isHiringOrInvestor);

  // tabs
  String _activeTab = 'registrations';

  // data
  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _submissions = [];

  // fast lookup: leaderId -> members[]
  final Map<String, List<Map<String, dynamic>>> _membersByLeaderId = {};

  // evaluation drafts (plus lock flag)
  final Map<String, Map<String, dynamic>> _drafts = {};

  // publish state
  bool _publishing = false;
  bool _resultsPublished = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthProvider?>()?.user;
    _role = (me?.role ?? '').toLowerCase();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isAdminContext) {
        final id = widget.competitionId!;
        final res = await Future.wait([
          _api.getCompetitionRegistrations(id),      // GET /competitions/:id/registrations
          _api.listSubmissionsByCompetition(id),     // GET /submissions/competition/:id
        ]);

        final regsRaw = (res[0]?['data']?['registrations'] as List?) ?? const [];
        final subsRaw = (res[1]?['data']?['submissions'] as List?) ??
            (res[1]?['submissions'] as List?) ?? const [];

        _registrations = _dedupeKeepNewest(regsRaw);
        _submissions = _dedupeKeepNewest(subsRaw);

        // build membersByLeaderId
        _membersByLeaderId.clear();
        for (final r in _registrations) {
          final leader = (r['leader'] as Map?) ?? const {};
          final leaderId = (leader['id'] ?? leader['_id'] ?? '').toString();
          final members = ((r['teamMembers'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (leaderId.isNotEmpty) _membersByLeaderId[leaderId] = members;
        }

        // attach team members to submissions (from registrations)
        _submissions = _submissions.map((s) {
          final leader = (s['leader'] as Map?) ?? (s['user'] as Map?) ?? const {};
          final leaderId = (leader['id'] ?? leader['_id'] ?? '').toString();
          final members = _membersByLeaderId[leaderId] ?? const <Map<String, dynamic>>[];
          return {...s, 'teamMembers': members};
        }).toList();

        // consider results "published" if any submission has status published
        _resultsPublished = _submissions.any((s) => (s['status']?.toString() ?? '').toLowerCase() == 'published');

        // init drafts (+ lock existing evaluated)
        _drafts.clear();
        for (final s in _submissions) {
          final sid = _sid(s);
          final alreadyEvaluated = (s['final_score'] != null) ||
              (((s['status'] ?? '') as String).isNotEmpty && s['status'] != 'submitted');
          _drafts[sid] = {
            'status': s['status'] ?? 'submitted',
            'final_score': (s['final_score'] ?? '').toString(),
            'feedback': s['feedback'] ?? '',
            'saving': false,
            'err': null,
            'locked': alreadyEvaluated, // lock if BE says it's already evaluated
          };
        }
      } else {
        final res = await _api.listMySubmissions(); // GET /submissions/my
        final listRaw = (res['data']?['submissions'] as List?) ??
            (res['submissions'] as List?) ?? const [];
        _submissions = _dedupeKeepNewest(listRaw);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateDraft(String sid, Map<String, dynamic> patch) {
    final curr = _drafts[sid] ?? {};
    _drafts[sid] = {...curr, ...patch};
    setState(() {});
  }

  Future<void> _saveEvaluation(Map<String, dynamic> s) async {
    if (!_isAdmin) return;
    final sid = _sid(s);
    final d = _drafts[sid] ?? {};
    _updateDraft(sid, {'saving': true, 'err': null});
    try {
      final payload = <String, dynamic>{'status': d['status'] ?? 'submitted'};
      final fs = (d['final_score'] ?? '').toString().trim();
      if (fs.isNotEmpty) {
        final n = double.tryParse(fs);
        if (n != null) payload['final_score'] = n;
      }
      final fb = (d['feedback'] ?? '').toString().trim();
      if (fb.isNotEmpty) payload['feedback'] = fb;

      await _api.updateSubmission(sid, payload);

      final idx = _submissions.indexWhere((x) => _sid(x) == sid);
      if (idx != -1) {
        _submissions[idx] = {..._submissions[idx], ...payload};
      }
      // 🔒 lock after first successful save
      _updateDraft(sid, {'saving': false, 'locked': true});
    } catch (e) {
      _updateDraft(sid, {'saving': false, 'err': e.toString()});
    }
  }

  Future<void> _publishResults() async {
    if (!_isAdmin || widget.competitionId == null) return;
    setState(() => _publishing = true);
    try {
      await _api.publishCompetitionResults(widget.competitionId!);
      if (!mounted) return;
      setState(() => _resultsPublished = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Results published')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _goToVideo(Map<String, dynamic> s) {
    final vid = _getVideoId(s);
    if (vid.isNotEmpty) {
      context.push('/main?tab=feed&video=$vid');
      return;
    }
    final url = (s['video_url'] ?? s['video']?['url'])?.toString();
    if (url != null && url.isNotEmpty) {
      final params = Uri(queryParameters: {
        'tab': 'feed',
        'videoUrl': url,
        if ((s['title'] ?? s['project_title']) != null)
          'title': (s['title'] ?? s['project_title']).toString(),
        if ((s['summary'] ?? '') != '') 'desc': (s['summary'] ?? '').toString(),
      }).query;
      context.push('/main?$params');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isAdminContext
        ? (_isAdmin ? 'Competition Management' : 'Competition Viewer')
        : 'My Submissions';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        // ⬇️ publish button moved out of the AppBar per request
        actions: const [],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
                ? _errorView()
                : _isAdminContext
                    ? _adminOrViewerBody()
                    : _userBody(),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Failed to load data', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // ---------------- user mode ----------------
  Widget _userBody() {
    if (_submissions.isEmpty) {
      return const Center(child: Text('No submissions yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _submissions.length,
      itemBuilder: (ctx, i) => _submissionCardUser(_submissions[i]),
    );
  }

  Widget _submissionCardUser(Map<String, dynamic> s) {
    final status = _statusText(s['status']);
    final fs = s['final_score'];
    final hasVideo = _getVideoId(s).isNotEmpty || (s['video_url'] != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _statusChip(status),
                if (fs != null)
                  Text(
                    (double.tryParse('$fs') ?? 0).toStringAsFixed(1),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (s['title'] ?? s['project_title'] ?? 'Untitled Project').toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if ((s['summary'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                s['summary'].toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((s['repo_url'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.code),
                    onPressed: () => _launchUrl(s['repo_url'].toString()),
                    label: const Text('Repository'),
                  ),
                if ((s['drive_url'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_shared_outlined),
                    onPressed: () => _launchUrl(s['drive_url'].toString()),
                    label: const Text('Drive'),
                  ),
                if ((s['zip_url'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _launchUrl(s['zip_url'].toString()),
                    label: const Text('Download'),
                  ),
              ],
            ),
            if (hasVideo) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () => _goToVideo(s),
                label: const Text('Watch Video'),
              ),
            ],
            if ((s['feedback'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Feedback',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(s['feedback'].toString()),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  // --------------- admin / viewer (hiring/investor) ---------------
  Widget _adminOrViewerBody() {
    return Column(
      children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
                ),
                alignment: Alignment.center,
                child: Icon(_isAdmin ? Icons.manage_search : Icons.visibility_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isAdmin ? 'Competition Management' : 'Competition Viewer',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      _isAdmin
                          ? 'Review registrations and evaluate submissions'
                          : 'View registrations and submissions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _tabBtn('registrations', 'Registrations (${_registrations.length})')),
              const SizedBox(width: 8),
              Expanded(child: _tabBtn('submitted', 'Submitted (${_submissions.length})')),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Submitted tab top row with Publish on right
        if (_activeTab == 'submitted')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _resultsPublished ? 'Results are published' : 'Evaluate or review submissions',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                if (_isAdmin)
                  FilledButton.icon(
                    onPressed: _resultsPublished || _publishing ? null : _publishResults,
                    icon: _publishing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.publish_outlined),
                    label: Text(_resultsPublished ? 'Published' : 'Publish'),
                  ),
              ],
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _activeTab == 'registrations' ? _registrationsList() : _submissionsList(),
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(String key, String label) {
    final selected = _activeTab == key;
    return OutlinedButton(
      onPressed: () => setState(() => _activeTab = key),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Theme.of(context).colorScheme.surface : null,
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.outline
              : Theme.of(context).colorScheme.outline.withOpacity(.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? null : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ---- Registrations (click → profile with contact) ----
  Widget _registrationsList() {
    if (_registrations.isEmpty) return const _ListEmpty('No registrations yet');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _registrations.length,
      itemBuilder: (ctx, i) {
        final reg = _registrations[i];
        final leader = reg['leader'] as Map? ?? const {};
        final name = (leader['name'] ?? 'Unknown').toString();
        final email = (leader['email'] ?? '').toString();
        final type = (reg['type'] ?? '').toString();
        final members = (reg['teamMembers'] as List?)?.length ?? 0;
        final createdAt = reg['created_at'];

        return InkWell(
          onTap: () => _openProfileFromUser(leader as Map<String, dynamic>),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.groups_2_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(email,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        if (type == 'team')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Team • $members member(s)',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Registered',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(
                        createdAt != null
                            ? DateTime.tryParse(createdAt.toString())
                                    ?.toLocal()
                                    .toString()
                                    .split('.')
                                    .first ??
                                '—'
                            : '—',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- Submitted (admin can evaluate; hiring/investor read-only) ----
  Widget _submissionsList() {
    if (_submissions.isEmpty) return const _ListEmpty('No submissions yet');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _submissions.length,
      itemBuilder: (ctx, i) => _submissionCardAdminView(_submissions[i]),
    );
  }

  Widget _submissionCardAdminView(Map<String, dynamic> s) {
    final sid = _sid(s);
    final d = _drafts[sid] ?? {};
    final hasVideo = _getVideoId(s).isNotEmpty || (s['video_url'] != null);
    final statusStr = _statusText(s['status']);

    final leader = (s['user'] as Map?) ?? (s['leader'] as Map?) ?? const {};
    final teamMembers = ((s['teamMembers'] as List?) ?? const []).cast<Map>();

    // 🔒 lock if previously evaluated OR marked locked after first save
    final bool locked = (d['locked'] == true) ||
        (s['final_score'] != null) ||
        (((s['status'] ?? '') as String).isNotEmpty && s['status'] != 'submitted');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Text(
                    (s['title'] ?? s['project_title'] ?? 'Untitled Project').toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusChip(statusStr),
                if (locked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(width: 6),
                      Icon(Icons.lock, size: 16),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _openProfileFromUser(leader as Map<String, dynamic>),
              child: Text(
                'by ${leader['name'] ?? leader['email'] ?? 'Unknown'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, decoration: TextDecoration.underline),
              ),
            ),

            if ((s['summary'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                s['summary'].toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((s['repo_url'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_zip_outlined),
                    onPressed: () => _launchUrl(s['repo_url'].toString()),
                    label: const Text('Repository'),
                  ),
                if (hasVideo)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => _goToVideo(s),
                    label: const Text('Watch Video'),
                  ),
                if ((s['drive_url'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.description_outlined),
                    onPressed: () => _launchUrl(s['drive_url'].toString()),
                    label: const Text('Drive'),
                  ),
                if ((s['zip_url'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _launchUrl(s['zip_url'].toString()),
                    label: const Text('Download'),
                  ),
              ],
            ),

            if (teamMembers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Team Members',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in teamMembers)
                    ActionChip(
                      label: Text(
                        '${m['name'] ?? ''} · ${m['email'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _openProfileFromUser(m as Map<String, dynamic>),
                    ),
                ],
              ),
            ],

            if (_isAdmin) ...[
              const SizedBox(height: 12),
              IgnorePointer(
                ignoring: locked,
                child: Opacity(
                  opacity: locked ? 0.6 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Evaluate Submission',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: DropdownButtonFormField<String>(
                                value: _STATUS_OPTIONS.contains(d['status']) ? d['status'] as String : 'submitted',
                                decoration: const InputDecoration(labelText: 'Status'),
                                items: _STATUS_OPTIONS
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e.replaceAll('_', ' '))))
                                    .toList(),
                                onChanged: locked ? null : (v) => _updateDraft(sid, {'status': v}),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: TextFormField(
                                initialValue: d['final_score'],
                                decoration: const InputDecoration(labelText: 'Final Score', hintText: 'e.g. 87.5'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: locked ? null : (v) => _updateDraft(sid, {'final_score': v}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          initialValue: d['feedback'],
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Feedback',
                            hintText: 'Write feedback for the participant…',
                          ),
                          onChanged: locked ? null : (v) => _updateDraft(sid, {'feedback': v}),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: (d['saving'] == true || locked) ? null : () => _saveEvaluation(s),
                              child: Text(d['saving'] == true ? 'Saving…' : 'Save Evaluation'),
                            ),
                            if (locked)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text('Locked after save', style: TextStyle(fontStyle: FontStyle.italic)),
                              ),
                            if ((d['err'] ?? '').toString().isNotEmpty)
                              Text(d['err'].toString(), style: TextStyle(color: Colors.red.shade300)),
                          ],
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- profile helpers (leader/member) ----
  void _openProfileFromUser(Map<String, dynamic> u) {
    final profile = {
      'name': u['name'],
      'email': u['email'],
      'phone': u['phone'],
      'college': u['college'],
      'branch': u['branch'],
      'year': u['year'],
    };
    _openProfileSheet(profile);
  }

  Future<void> _openProfileSheet(Map<String, dynamic> profile) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(ctx).colorScheme.primary,
                            Theme.of(ctx).colorScheme.primary.withOpacity(0.7),
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Participant Details',
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(ctx).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (profile['name'] ?? 'Unknown User').toString(),
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Profile Information Cards
                _buildProfileCard(ctx, 'Email', profile['email'], Icons.email_outlined),
                _buildProfileCard(ctx, 'Phone', profile['phone'], Icons.phone_outlined),
                _buildProfileCard(ctx, 'College', profile['college'], Icons.school_outlined),
                _buildProfileCard(ctx, 'Branch', profile['branch'], Icons.engineering_outlined),
                _buildProfileCard(ctx, 'Year', profile['year'], Icons.calendar_today_outlined),
                
                const SizedBox(height: 24),
                
                // Contact Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openContactDialog(profile),
                    icon: const Icon(Icons.message_outlined, size: 18),
                    label: const Text('Contact'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildProfileCard(BuildContext ctx, String label, dynamic value, IconData icon) {
    final txt = (value ?? '—').toString();
    final isEmpty = txt == '—' || txt.isEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty 
          ? Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty 
            ? Theme.of(ctx).colorScheme.outline.withOpacity(0.2)
            : Theme.of(ctx).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isEmpty 
                ? Theme.of(ctx).colorScheme.surfaceContainerHighest
                : Theme.of(ctx).colorScheme.primaryContainer,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isEmpty 
                ? Theme.of(ctx).colorScheme.onSurfaceVariant.withOpacity(0.5)
                : Theme.of(ctx).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  txt,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: isEmpty 
                      ? Theme.of(ctx).colorScheme.onSurfaceVariant.withOpacity(0.6)
                      : Theme.of(ctx).colorScheme.onSurface,
                    fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, dynamic value) {
    final txt = (value ?? '—').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(txt, style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }

  void _launchUrl(String url) async {
    final ok = await canLaunchUrlString(url);
    if (ok) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot open: $url')));
    }
  }

  Future<void> _openContactDialog(Map<String, dynamic> profile) async {
    final name = (profile['name'] ?? 'Unknown User').toString();
    final email = (profile['email'] ?? '').toString();
    final role = 'student'; // Default role for participants
    
    // Navigate to contact screen with user details
    if (mounted) {
      context.push('/contact/${email}', extra: {
        'userName': name,
        'userRole': role,
        'userEmail': email,
      });
    }
  }
}

class _ListEmpty extends StatelessWidget {
  final String label;
  const _ListEmpty(this.label);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
