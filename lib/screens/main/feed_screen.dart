import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';

import '../../core/services/api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../widgets/reel_item.dart';

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

/* --------------------------------- screen ---------------------------------- */

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _api = ApiService();
  final PageController _pageController = PageController();

  // Filter state
  String? _selectedTag;
  final List<String> _filterOptions = ['All', 'ai', 'ml', 'web', 'frontend'];

  // Paging
  final int _limit = 10;
  int _page = 1;
  bool _hasNext = true;

  // Data
  bool _loading = true;
  bool _fetchingMore = false;
  String? _error;
  List<Map<String, dynamic>> _videos = <Map<String, dynamic>>[];

  // Current visible index
  int _currentIndex = 0;

  // Video controllers per index
  final Map<int, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleUrlParams();
      _loadFeed(reset: true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  void _disposeAllControllers() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _controllers.clear();
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
    copy['title'] = fix(v['title']);
    copy['description'] = fix(v['description']);

    final u = (v['uploader'] is Map) ? Map<String, dynamic>.from(v['uploader']) : <String, dynamic>{};
    copy['uploader'] = {
      'id'      : '${u['id'] ?? u['_id'] ?? ''}',
      'name'    : '${u['name'] ?? u['fullName'] ?? 'Unknown'}',
      'role'    : '${u['role'] ?? ''}'.toLowerCase(),
      'email'   : '${u['email'] ?? ''}',
      'phone'   : '${u['phone'] ?? ''}',
      'country' : '${u['country'] ?? ''}',
      'college' : '${u['college'] ?? ''}',
      'branch'  : '${u['branch'] ?? ''}',
      'year'    : '${u['year'] ?? ''}',
      'company' : '${u['company_name'] ?? u['company'] ?? ''}',
      'firm'    : '${u['firm_name'] ?? ''}',
      'website' : '${u['website'] ?? u['company_website'] ?? ''}',
      'avatar'  : '${u['avatar'] ?? u['avatar_url'] ?? ''}',
      'bio'     : '${u['bio'] ?? u['description'] ?? ''}',
      'skills'  : u['skills'] is List ? (u['skills'] as List).cast<String>() : <String>[],
      'linkedin': '${u['linkedin'] ?? ''}',
      'github'  : '${u['github'] ?? ''}',
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
      final featured = _normalizeMedia({
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
      setState(() {
        _videos.insert(0, featured);
      });
      return;
    }

    if (videoParam != null && videoParam.isNotEmpty) {
      final decoded = Uri.decodeComponent(videoParam);
      final looksLikeUrl = decoded.startsWith('http://') || decoded.startsWith('https://');
      if (looksLikeUrl) {
        final featured = _normalizeMedia({
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
        setState(() {
          _videos.insert(0, featured);
        });
      } else {
        _loadSpecificVideoById(decoded);
      }
    }
  }

  Future<void> _loadSpecificVideoById(String id) async {
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
            _videos.insert(0, norm);
          });
        }
      }
    } catch (_) {}
  }

  /* ------------------------------------ API ------------------------------------ */

  Future<void> _loadFeed({required bool reset}) async {
    try {
      if (reset) {
        if (!mounted) return;
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
          _hasNext = true;
        });
        _disposeAllControllers();
      } else {
        if (!_hasNext || _fetchingMore) return;
        if (!mounted) return;
        setState(() => _fetchingMore = true);
      }

      // Get current user role for filtering
      final auth = context.read<AuthProvider?>();
      final currentUser = auth?.user;
      final currentUserRole = (currentUser?.role ?? '').toLowerCase();
      
      final res = await _api.getFeed(
        page: reset ? 1 : _page,
        limit: _limit,
        search: _selectedTag == 'All' ? null : _selectedTag,
        uploader: (currentUserRole == 'student' || currentUserRole == 'user') 
            ? currentUser?.id 
            : null, // Students only see their own videos, others see all
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
            _currentIndex = 0;
            if (_videos.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _pageController.jumpToPage(0);
                _playVideo(0);
              });
            }
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
    } catch (e, st) { // ✅ FIX: Changed from catch(_) to catch(e, st)
      if (!mounted) return;
      // ✅ FIX: Print the actual error to the console for debugging
      debugPrint('----------- FEED LOAD ERROR -----------');
      debugPrint('Error: $e');
      debugPrint('Stack Trace: $st');
      debugPrint('------------------------------------');
      setState(() => _error = 'Error processing feed data. Check console.');
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _fetchingMore = false;
      });
    }
  }

  /* -------------------------------- video playback -------------------------------- */

  void _playVideo(int index) {
    if (index < 0 || index >= _videos.length) return;
    final video = _videos[index];
    final url = '${video['url'] ?? ''}';

    // Pause all other videos
    for (final entry in _controllers.entries) {
      if (entry.key != index) {
        entry.value.pause();
      }
    }

    if (!_isDirectVideoUrl(url)) return;

    if (!_controllers.containsKey(index)) {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _controllers[index] = ctrl;
      ctrl.initialize().then((_) {
        if (!mounted) return;
        ctrl.setLooping(true);
        ctrl.play();
        setState(() {});
      });
    } else {
      final ctrl = _controllers[index]!;
      if (ctrl.value.isInitialized) {
        ctrl.play();
      }
    }
  }



  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _playVideo(index);

    // Preload next 2
    for (int i = index + 1; i <= index + 2 && i < _videos.length; i++) {
      final v = _videos[i];
      final url = '${v['url'] ?? ''}';
      if (_isDirectVideoUrl(url) && !_controllers.containsKey(i)) {
        final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
        _controllers[i] = ctrl;
        ctrl.initialize();
      }
    }

    // Load more if near end
    if (index >= _videos.length - 3 && _hasNext && !_fetchingMore) {
      _loadFeed(reset: false);
    }
  }

  /* ------------------------------ profile sheet ------------------------------ */

  void _openUploaderProfile(Map<String, dynamic> uploader) {
    final id = '${uploader['id'] ?? ''}';
    if (id.isNotEmpty) {
      // Check current user's role and implement role-based access
      final auth = context.read<AuthProvider?>();
      final currentUser = auth?.user;
      final currentUserRole = (currentUser?.role ?? '').toLowerCase();
      
      // Only admin, hiring, investor can view profiles
      if (currentUserRole == 'admin' || currentUserRole == 'hiring' || currentUserRole == 'investor') {
        // Show profile modal instead of navigating to separate screen
        _openProfileSheet(uploader);
      } else {
        // Students cannot view any profiles
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot view user profiles')),
        );
        return;
      }
    }
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
                            'User Profile',
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

  Future<void> _openContactDialog(Map<String, dynamic> profile) async {
    final name = (profile['name'] ?? 'Unknown User').toString();
    final email = (profile['email'] ?? '').toString();
    final role = (profile['role'] ?? 'student').toString();
    
    // Navigate to contact screen with user details
    if (mounted) {
      context.push('/contact/${email}', extra: {
        'userName': name,
        'userRole': role,
        'userEmail': email,
      });
    }
  }

  /* ----------------------------------- UI ----------------------------------- */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading && _videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (_error != null && _videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadFeed(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_outlined, size: 56, color: Colors.grey),
              SizedBox(height: 16),
              Text('No videos found', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main reels viewer
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              final controller = _controllers[index];
              return ReelItem(
                video: video,
                controller: controller,
                isActive: index == _currentIndex,
                onTapProfile: _openUploaderProfile,
                onLike: () {
                  // TODO: Implement like logic (API call)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Like feature coming soon!')),
                  );
                },
                onComment: () {
                  // TODO: Implement comment sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comments coming soon!')),
                  );
                },
                onShare: () {
                  // TODO: Implement share
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon!')),
                  );
                },
              );
            },
          ),

          // Top-right filter dropdown
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _FilterDropdown(
              selected: _selectedTag ?? 'All',
              options: _filterOptions,
              onChanged: (val) {
                setState(() => _selectedTag = val == 'All' ? null : val);
                _loadFeed(reset: true);
              },
            ),
          ),

          // Loading more indicator at bottom
          if (_fetchingMore)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading more...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------- filter dropdown ------------------------------ */

class _FilterDropdown extends StatelessWidget {
  final String selected;
  final List<String> options;
  final void Function(String) onChanged;

  const _FilterDropdown({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              selected,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          ],
        ),
      ),
      color: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => options.map((option) {
        final isSelected = option == selected;
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            children: [
              if (isSelected)
                const Icon(Icons.check, color: Colors.white, size: 18)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(
                option,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

