import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';

/* --------------------------- helpers / formatters --------------------------- */

int asInt(dynamic x) {
  if (x == null) return 0;
  if (x is int) return x;
  if (x is num) return x.toInt();
  return int.tryParse('$x') ?? 0;
}

String fmtLen(dynamic sec) {
  final s = asInt(sec);
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

String fmtAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '—';
  final diff = DateTime.now().difference(dt);
  final m = diff.inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '${m}m ago';
  final h = diff.inHours;
  if (h < 24) return '${h}h ago';
  final d = diff.inDays;
  if (d < 7) return '${d}d ago';
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${dt.day} ${months[dt.month - 1]}';
}

bool _isDirectVideoUrl(String url) {
  final u = url.toLowerCase();
  return u.endsWith('.mp4') || u.endsWith('.webm') || u.endsWith('.m3u8');
}

/* ----------------------------- scroll behavior ----------------------------- */

class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // hide scrollbars
  }
}

/* --------------------------------- screen ---------------------------------- */

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();

  // search
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // scroll + paging
  final _scroll = ScrollController();
  final int _limit = 12;
  int _page = 1;
  bool _hasNext = true;

  // data
  bool _loading = true;
  bool _fetchingMore = false;
  bool _loadingSpecific = false;
  String? _error;
  List<Map<String, dynamic>> _videos = <Map<String, dynamic>>[];

  // featured / expanded
  Map<String, dynamic>? _specificVideo;
  String? _expandedKey; // 'specific' or '$index'

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

    _scroll.addListener(_onScrollLoadMore);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleUrlParams();
      _loadFeed(reset: true);
      _anim.forward();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _scroll.removeListener(_onScrollLoadMore);
    _scroll.dispose();
    _anim.dispose();
    super.dispose();
  }

  /* -------------------------------- normalize -------------------------------- */

  Map<String, dynamic> _normalizeMedia(Map<String, dynamic> v) {
    final copy = Map<String, dynamic>.from(v);
    String fix(dynamic u) => (u is String) ? u : '';
    copy['id'] = fix(v['id'] ?? v['_id']);
    copy['url'] = fix(v['url']);
    copy['thumbnail_url'] = fix(v['thumbnail_url'] ?? v['thumbnailUrl']);
    copy['views_count'] = asInt(v['views_count'] ?? v['viewsCount']);
    copy['likes_count'] = asInt(v['likes_count'] ?? v['likesCount']);
    copy['length_sec'] = asInt(v['length_sec'] ?? v['lengthSec']);
    copy['created_at'] = fix(v['created_at'] ?? v['createdAt']);

    // Normalize uploader info for the profile sheet
    final u = (v['uploader'] is Map) ? Map<String, dynamic>.from(v['uploader']) : <String, dynamic>{};
    copy['uploader'] = {
      'id'      : '${u['id'] ?? u['_id'] ?? ''}',
      'name'    : '${u['name'] ?? u['fullName'] ?? 'Unknown'}',
      'role'    : '${u['role'] ?? ''}'.toLowerCase(), // student | hiring | investor | admin
      'email'   : '${u['email'] ?? ''}',
      'phone'   : '${u['phone'] ?? ''}',
      'college' : '${u['college'] ?? ''}',
      'company' : '${u['company_name'] ?? u['company'] ?? ''}',
      'firm'    : '${u['firm_name'] ?? ''}',
      'website' : '${u['website'] ?? u['company_website'] ?? ''}',
      'avatar'  : '${u['avatar'] ?? u['avatar_url'] ?? ''}',
    };
    return copy;
  }

  /* --------------------------------- URL params -------------------------------- */

  void _handleUrlParams() {
    final uri = GoRouterState.of(context).uri;

    final videoParam = uri.queryParameters['video'];
    final videoUrlParam = uri.queryParameters['videoUrl'];
    final titleParam = uri.queryParameters['title'] ?? '';
    final descParam = uri.queryParameters['desc'] ?? '';

    if (videoUrlParam != null && videoUrlParam.isNotEmpty) {
      final url = Uri.decodeComponent(videoUrlParam);
      _specificVideo = _normalizeMedia({
        'id': 'url-featured',
        'url': url,
        'thumbnail_url': '',
        'title': titleParam.isNotEmpty ? titleParam : 'Shared video',
        'description': descParam,
        'tags': <String>[],
        'views_count': 0,
        'likes_count': 0,
        'length_sec': 0,
        'created_at': DateTime.now().toIso8601String(),
        'uploader': {'name': 'Shared', 'role': 'student'},
      });
      _expandedKey = 'specific';
      return;
    }

    if (videoParam != null && videoParam.isNotEmpty) {
      final decoded = Uri.decodeComponent(videoParam);
      final looksLikeUrl = decoded.startsWith('http://') || decoded.startsWith('https://');
      if (looksLikeUrl) {
        _specificVideo = _normalizeMedia({
          'id': 'url-featured',
          'url': decoded,
          'thumbnail_url': '',
          'title': titleParam.isNotEmpty ? titleParam : 'Shared video',
          'description': descParam,
          'tags': <String>[],
          'views_count': 0,
          'likes_count': 0,
          'length_sec': 0,
          'created_at': DateTime.now().toIso8601String(),
          'uploader': {'name': 'Shared', 'role': 'student'},
        });
        _expandedKey = 'specific';
      } else {
        _loadSpecificVideoById(decoded);
      }
    }
  }

  void _clearVideoQueryParams() {
    final uri = GoRouterState.of(context).uri;
    final qp = Map<String, String>.from(uri.queryParameters);
    qp.remove('video');
    qp.remove('videoUrl');
    qp.remove('title');
    qp.remove('desc');
    final next = uri.replace(queryParameters: qp.isEmpty ? null : qp).toString();
    context.go(next);
  }

  /* ------------------------------------ API ------------------------------------ */

  Future<void> _loadSpecificVideoById(String id) async {
    if (!mounted) return;
    setState(() => _loadingSpecific = true);
    try {
      final res = await _api.getVideoById(id);
      if (!mounted) return;
      final ok = (res is Map) && (res['success'] == true);
      if (ok) {
        final data = res['data'] ?? res;
        final v = data['video'] ?? data;
        if (v is Map) {
          final norm = _normalizeMedia(Map<String, dynamic>.from(v));
          setState(() {
            _specificVideo = norm;
            _expandedKey = 'specific';
          });
        }
      } else {
        setState(() => _error = 'Failed to load video');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load video');
    } finally {
      if (!mounted) return;
      setState(() => _loadingSpecific = false);
    }
  }

  Future<void> _loadFeed({required bool reset}) async {
    try {
      if (reset) {
        if (!mounted) return;
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
          _hasNext = true;
          _expandedKey = null;
        });
      } else {
        if (!_hasNext || _fetchingMore) return;
        if (!mounted) return;
        setState(() => _fetchingMore = true);
      }

      final res = await _api.getFeed(
        page: reset ? 1 : _page,
        limit: _limit,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );

      if (!mounted) return;

      if (res is Map &&
          (res['success'] == true || res['videos'] != null || res['data'] != null)) {
        final data = res['data'] ?? res;
        final listDynamic = (data['videos'] ?? []) as List<dynamic>;
        final fetched = listDynamic
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map(_normalizeMedia)
            .toList();

        final next = (data['pagination'] is Map)
            ? (data['pagination']['hasNextPage'] == true)
            : fetched.length == _limit;

        setState(() {
          if (reset) {
            _videos = fetched;
            _page = 2;
          } else {
            _videos = [..._videos, ...fetched];
            _page += 1;
          }
          _hasNext = next;
          _error = null;
        });
      } else {
        setState(() => _error =
            (res is Map ? (res['message'] as String?) : null) ?? 'Failed to load feed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Network error');
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _fetchingMore = false;
      });
    }
  }

  /* -------------------------------- behaviors -------------------------------- */

  void _onScrollLoadMore() {
    if (!_hasNext || _fetchingMore || _loading) return;
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final cur = _scroll.position.pixels;
    if (max - cur < 480) {
      _loadFeed(reset: false);
    }
  }

  void _debouncedSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _loadFeed(reset: true);
    });
  }

  void _toggleExpanded(String key) {
    if (!mounted) return;
    setState(() {
      _expandedKey = (_expandedKey == key) ? null : key;
    });
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /* ------------------------------ profile sheet ------------------------------ */

  void _openUploaderProfile(Map<String, dynamic> uploader) {
    final role = '${uploader['role'] ?? ''}'.toLowerCase();
    final isContactable = role == 'admin' || role == 'hiring' || role == 'investor';

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfileSheet(
        uploader: uploader,
        isContactable: isContactable,
        onContact: () => _contactUploader(uploader),
        onViewFull: () {
          final id = '${uploader['id'] ?? ''}';
          if (id.isNotEmpty) context.push('/profile/$id'); // ensure route exists if you want
        },
      ),
    );
  }

  Future<void> _contactUploader(Map<String, dynamic> u) async {
    // prefer email > phone > website
    final email = '${u['email'] ?? ''}';
    final phone = '${u['phone'] ?? ''}';
    final site  = '${u['website'] ?? ''}';

    if (email.isNotEmpty) {
      final uri = Uri(scheme: 'mailto', path: email, query: 'subject=PPL%20Inquiry');
      await launchUrl(uri);
      return;
    }
    if (phone.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: phone);
      await launchUrl(uri);
      return;
    }
    if (site.isNotEmpty) {
      final uri = Uri.tryParse(site.startsWith('http') ? site : 'https://$site');
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact info available')),
      );
    }
  }

  /* ----------------------------------- UI ----------------------------------- */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Feed'), elevation: 0),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: _NoScrollbarBehavior(),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: RefreshIndicator(
                onRefresh: () => _loadFeed(reset: true),
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverToBoxAdapter(child: _buildHeader(theme)),
                    ),

                    if (_loading && _specificVideo == null)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: _TopLoader(),
                        ),
                      ),

                    if (_loadingSpecific)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ),
                        ),
                      ),

                    if (_error != null && !_loading && _specificVideo == null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: _ErrorCard(
                            message: _error!,
                            onRetry: () => _loadFeed(reset: true),
                          ),
                        ),
                      ),

                    if (_error == null && !_loading && _specificVideo == null && _videos.isEmpty)
                      const SliverToBoxAdapter(child: _EmptyState()),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverList.builder(
                        itemCount: (_specificVideo != null ? 1 : 0) + _videos.length,
                        itemBuilder: (ctx, idx) {
                          if (_specificVideo != null && idx == 0) {
                            return _VideoCard(
                              v: _specificVideo!,
                              isSpecific: true,
                              isExpanded: _expandedKey == 'specific',
                              onToggle: () => _toggleExpanded('specific'),
                              onCloseSpecific: () {
                                setState(() {
                                  _specificVideo = null;
                                  _expandedKey = null;
                                });
                                _clearVideoQueryParams();
                              },
                              onTapProfile: _openUploaderProfile,
                            );
                          }
                          final i = _specificVideo != null ? idx - 1 : idx;
                          final v = _videos[i];
                          final key = '$i';
                          return _VideoCard(
                            v: v,
                            isSpecific: false,
                            isExpanded: _expandedKey == key,
                            onToggle: () => _toggleExpanded(key),
                            onTapProfile: _openUploaderProfile,
                          );
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Center(
                          child: (_hasNext && _videos.isNotEmpty)
                              ? (_fetchingMore
                                  ? const _LoadingMoreRow()
                                  : const Opacity(
                                      opacity: 0.6,
                                      child: Text('Scroll to load more', style: TextStyle(fontSize: 12)),
                                    ))
                              : (_videos.isNotEmpty
                                  ? const Opacity(
                                      opacity: 0.6,
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text('You’ve reached the end', style: TextStyle(fontSize: 12)),
                                      ),
                                    )
                                  : const SizedBox.shrink()),
                        ),
                      ),
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

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + subtitle
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Feed', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                'Watch 60-sec submissions from the community',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // Search
        TextField(
          controller: _searchCtrl,
          onChanged: _debouncedSearch,
          decoration: InputDecoration(
            hintText: 'Search videos, descriptions...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: (_searchCtrl.text.isNotEmpty)
                ? IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _loadFeed(reset: true);
                      if (mounted) setState(() {});
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
}

/* ============================= small widgets ============================= */

class _TopLoader extends StatelessWidget {
  const _TopLoader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline.withOpacity(0.2),
            borderRadius: BorderRadius.circular(999),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.35,
              child: Container(
                height: 6,
                color: theme.colorScheme.primary.withOpacity(0.4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Error loading feed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade300),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.movie_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text('No videos found',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Try a different search or check back later',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          const Opacity(
            opacity: 0.9,
            child: Text('Loading more videos...', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------- video card ------------------------------- */

class _VideoCard extends StatefulWidget {
  final Map<String, dynamic> v;
  final bool isSpecific;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onCloseSpecific;
  final void Function(Map<String, dynamic> uploader) onTapProfile;

  const _VideoCard({
    super.key,
    required this.v,
    required this.isSpecific,
    required this.isExpanded,
    required this.onToggle,
    this.onCloseSpecific,
    required this.onTapProfile,
  });

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _vp;
  Future<void>? _vpInit;

  String get _title => '${widget.v['title'] ?? ''}';
  Map<String, dynamic> get _uploader => (widget.v['uploader'] as Map<String, dynamic>? ?? {});
  String get _uploaderName => '${_uploader['name'] ?? 'Unknown'}';
  String get _uploaderRole => '${_uploader['role'] ?? ''}';
  String get _createdAt => '${widget.v['created_at'] ?? ''}';

  String get _url => '${widget.v['url'] ?? ''}';
  String get _thumb => '${widget.v['thumbnail_url'] ?? ''}';
  int get _views => asInt(widget.v['views_count'] ?? widget.v['viewsCount']);
  int get _likes => asInt(widget.v['likes_count'] ?? widget.v['likesCount']);
  int get _lenSec => asInt(widget.v['length_sec'] ?? widget.v['lengthSec']);

  @override
  void initState() {
    super.initState();
    _maybePreparePlayer();
  }

  @override
  void didUpdateWidget(covariant _VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.v != widget.v || oldWidget.isExpanded != widget.isExpanded) {
      _maybeDisposePlayer();
      _maybePreparePlayer();
    }
  }

  @override
  void dispose() {
    _maybeDisposePlayer();
    super.dispose();
  }

  void _maybePreparePlayer() {
    if (!widget.isExpanded) return;

    // Only direct video URLs are played inline
    if (_isDirectVideoUrl(_url)) {
      _vp = VideoPlayerController.networkUrl(Uri.parse(_url));
      _vpInit = _vp!.initialize().then((_) {
        if (!mounted) return;
        _vp!.setLooping(true);
        _vp!.play();
        setState(() {});
      });
    }
  }

  void _maybeDisposePlayer() {
    _vpInit = null;
    _vp?.dispose();
    _vp = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withOpacity(0.25);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isSpecific ? theme.colorScheme.primary.withOpacity(0.06) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER (instagram-like): avatar + name + role + time ... menu
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                _AvatarCircle(name: _uploaderName, avatarUrl: '${_uploader['avatar'] ?? ''}'),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onTapProfile(_uploader),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_uploaderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (_uploaderRole.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(_uploaderRole.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    )),
                              ),
                            const SizedBox(width: 8),
                            Text(fmtAgo(_createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isSpecific)
                  IconButton(
                    tooltip: 'Close',
                    onPressed: widget.onCloseSpecific,
                    icon: const Icon(Icons.close),
                  )
                else
                  IconButton(
                    onPressed: () {}, // future: report, share, copy link...
                    icon: const Icon(Icons.more_vert),
                  ),
              ],
            ),
          ),

          // CAPTION/TITLE
          if (_title.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),

          // Meta (duration, views, likes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _MetaRow(
              uploader: _uploaderName,
              duration: fmtLen(_lenSec),
              views: _views,
              likes: _likes,
            ),
          ),
          const SizedBox(height: 10),

          // Thumbnail / player area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _PlayerArea(
              isExpanded: widget.isExpanded,
              url: _url,
              thumb: _thumb,
              borderColor: borderColor,
              vp: _vp,
              vpInit: _vpInit,
              onTapToggle: widget.onToggle,
              onOpenExternally: () => _openExternally(_url, context),
            ),
          ),

          const SizedBox(height: 10),

          // ACTIONS (like, comment, share — visual only for now)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.mode_comment_outlined)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.send_outlined)),
                const Spacer(),
                IconButton(onPressed: widget.onToggle, icon: Icon(widget.isExpanded ? Icons.expand_less : Icons.expand_more)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _openExternally(String url, BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/* -------------------------- player / thumbnail area ------------------------- */

class _PlayerArea extends StatelessWidget {
  final bool isExpanded;
  final String url;
  final String thumb;
  final Color borderColor;
  final VideoPlayerController? vp;
  final Future<void>? vpInit;
  final VoidCallback onTapToggle;
  final VoidCallback onOpenExternally;

  const _PlayerArea({
    required this.isExpanded,
    required this.url,
    required this.thumb,
    required this.borderColor,
    required this.vp,
    required this.vpInit,
    required this.onTapToggle,
    required this.onOpenExternally,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget _thumbBox() => InkWell(
          onTap: onTapToggle,
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              image: (thumb.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(thumb), fit: BoxFit.cover)
                  : null,
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isExpanded ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        );

    if (!isExpanded) return _thumbBox();

    final controller = vp;
    final init = vpInit;

    if (_isDirectVideoUrl(url) && controller != null && init != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: borderColor)),
          child: FutureBuilder<void>(
            future: init,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return SizedBox(
                  height: 220,
                  child: Center(
                    child: SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }
              if (!controller.value.isInitialized) {
                return SizedBox(
                  height: 220,
                  child: Center(
                    child: Text('Video failed to load', style: Theme.of(context).textTheme.bodySmall),
                  ),
                );
              }
              return AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0 ? (16 / 9) : controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(controller),
                    _ControlsOverlay(controller: controller),
                    VideoProgressIndicator(controller, allowScrubbing: true),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    // Non-direct URLs (e.g., YouTube) → open externally
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _thumbBox(),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onOpenExternally,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open video'),
        ),
      ],
    );
  }
}

/* -------------------------- video control overlay -------------------------- */

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _ControlsOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.value.isPlaying ? controller.pause() : controller.play(),
      child: Stack(
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: controller.value.isPlaying
                ? const SizedBox.shrink()
                : Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(Icons.play_arrow, size: 64.0, color: Colors.white),
                    ),
                  ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ meta compact row --------------------------- */

class _MetaRow extends StatelessWidget {
  final String uploader;
  final String duration;
  final int views;
  final int likes;

  const _MetaRow({
    required this.uploader,
    required this.duration,
    required this.views,
    required this.likes,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = t.bodySmall?.color ?? Theme.of(context).colorScheme.onSurface;
    final base = (t.labelMedium ?? const TextStyle(fontSize: 12)).copyWith(fontWeight: FontWeight.w600);

    Widget dot() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('•', style: TextStyle(fontSize: 12, color: color!.withOpacity(0.7))),
        );

    Widget item(IconData icon, String text, {bool flex = false}) {
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(text, style: base, overflow: TextOverflow.ellipsis),
        ],
      );
      return flex ? Flexible(child: row) : row;
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 0,
          runSpacing: 4,
          children: [
            item(Icons.person_outline, uploader, flex: w < 360),
            dot(),
            item(Icons.access_time, duration),
            dot(),
            item(Icons.remove_red_eye_outlined, '$views'),
            dot(),
            item(Icons.favorite_border, '$likes'),
          ],
        );
      },
    );
  }
}

/* ------------------------------ avatar helper ------------------------------ */

class _AvatarCircle extends StatelessWidget {
  final String name;
  final String avatarUrl;
  const _AvatarCircle({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = () {
      final n = name.trim();
      if (n.isEmpty) return 'U';
      final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      return parts.length >= 2 ? (parts.first[0] + parts.last[0]).toUpperCase() : n[0].toUpperCase();
    }();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
        image: avatarUrl.isNotEmpty
            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: avatarUrl.isEmpty
          ? Text(initials, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold))
          : null,
    );
  }
}

/* ------------------------------ profile bottom sheet ----------------------- */

class _ProfileSheet extends StatelessWidget {
  final Map<String, dynamic> uploader;
  final bool isContactable;
  final VoidCallback onContact;
  final VoidCallback onViewFull;

  const _ProfileSheet({
    required this.uploader,
    required this.isContactable,
    required this.onContact,
    required this.onViewFull,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline.withOpacity(0.25);

    final name = '${uploader['name'] ?? 'Unknown'}';
    final role = '${uploader['role'] ?? ''}';
    final email = '${uploader['email'] ?? ''}';
    final phone = '${uploader['phone'] ?? ''}';
    final college = '${uploader['college'] ?? ''}';
    final company = '${uploader['company'] ?? ''}';
    final firm = '${uploader['firm'] ?? ''}';
    final website = '${uploader['website'] ?? ''}';
    final avatar = '${uploader['avatar'] ?? ''}';

    String primaryLine = '';
    if (role == 'student' && college.isNotEmpty) primaryLine = college;
    if (role == 'hiring' && company.isNotEmpty) primaryLine = company;
    if (role == 'investor' && firm.isNotEmpty) primaryLine = firm;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _AvatarCircle(name: name, avatarUrl: avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        if (role.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: border),
                            ),
                            child: Text(role.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )),
                          ),
                        if (primaryLine.isNotEmpty)
                          Text(primaryLine,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: border),
          const SizedBox(height: 12),

          // details list
          Column(
            children: [
              if (email.isNotEmpty) _kvRow(Icons.mail_outline, 'Email', email),
              if (phone.isNotEmpty) _kvRow(Icons.phone_outlined, 'Phone', phone),
              if (website.isNotEmpty) _kvRow(Icons.link_outlined, 'Website', website),
              if (role == 'student' && college.isNotEmpty) _kvRow(Icons.school_outlined, 'College', college),
              if (role == 'hiring' && company.isNotEmpty) _kvRow(Icons.business_outlined, 'Company', company),
              if (role == 'investor' && firm.isNotEmpty) _kvRow(Icons.account_balance_outlined, 'Firm', firm),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewFull,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('View Full Profile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isContactable
                    ? FilledButton.icon(
                        onPressed: onContact,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Contact'),
                      )
                    : FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Contact'),
                      ),
              ),
            ],
          ),

          // bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _kvRow(IconData icon, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          SizedBox(width: 88, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
