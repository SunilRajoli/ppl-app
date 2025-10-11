// lib/screens/competitions/main_nav_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
// ⬇️ Reuse the exact ThemeToggle used in GlobalTopBar
import '../../widgets/custom_widgets.dart'; // ThemeToggle

// Your existing screens
import '../landing_screen.dart';
import './competitions_screen.dart';
import './feed_screen.dart';
import './profile_screen.dart';

// ✅ Real Admin Hub screen
import '../admin/admin_hub_screen.dart';

enum _MenuAction { changePassword, logout }

class MainNavScreen extends StatefulWidget {
  /// 'home' | 'competition' | 'feed' | 'profile' | 'admin'
  final String initialTab;

  const MainNavScreen({super.key, this.initialTab = 'home'});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0; // temporary; we’ll jump after provider is ready
    _pageController = PageController(initialPage: _currentIndex);

    // Defer until first frame so Provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final isAdmin = (auth.user?.role ?? '').toLowerCase() == 'admin';
      final idx = _tabToIndex(widget.initialTab, isAdmin);
      _currentIndex = idx;
      _pageController.jumpToPage(idx);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Map a tab string to an index, respecting admin availability.
  int _tabToIndex(String tab, bool isAdmin) {
    switch (tab) {
      case 'home':
        return 0;
      case 'competition':
        return 1;
      case 'feed':
        return 2;
      case 'profile':
        return 3;
      case 'admin':
        return isAdmin ? 4 : 0; // fall back if no admin access
      default:
        return 0;
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _safeInitials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return 'U';
    final parts = n.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final first = parts.first;
      final take = first.length >= 2 ? 2 : 1;
      return first.substring(0, take).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _handleMenuAction(_MenuAction action) async {
    switch (action) {
      case _MenuAction.changePassword:
        if (!mounted) return;
        // ✅ GoRouter navigation (consistent with rest of app)
        context.push('/change-password');
        break;

      case _MenuAction.logout:
        final auth = context.read<AuthProvider>();
        await auth.logout(); // clear tokens/session etc.

        if (!mounted) return;
        // ✅ GoRouter stack reset to login
        context.go('/login');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isAdmin = (auth.user?.role ?? '').toLowerCase() == 'admin';

    // Pages list depends on role
    final pages = <Widget>[
      const LandingScreen(embedded: true),
      const CompetitionsScreen(),
      const FeedScreen(),
      const ProfileScreen(),
      if (isAdmin) const AdminHubScreen(),
    ];

    // If the current index is out of range (role changed), clamp & jump.
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
      _pageController.jumpToPage(_currentIndex);
    }

    // Bottom nav destinations
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events),
        label: 'Competition',
      ),
      const NavigationDestination(
        icon: Icon(Icons.feed_outlined),
        selectedIcon: Icon(Icons.feed),
        label: 'Feed',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin Hub',
        ),
    ];

    final initials = _safeInitials(auth.user?.name);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'P',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('PPL'),
          ],
        ),
        actions: [
          // ⬇️ Replaced notifications bell with the same toggle as GlobalTopBar
          const ThemeToggle(),
          const SizedBox(width: 6),

          PopupMenuButton<_MenuAction>(
            onSelected: _handleMenuAction, // ✅ runs after menu closes
            itemBuilder: (context) => <PopupMenuEntry<_MenuAction>>[
              PopupMenuItem<_MenuAction>(
                enabled: false,
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user?.name ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if ((auth.user?.email ?? '').isNotEmpty)
                          Text(
                            auth.user!.email,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<_MenuAction>(
                value: _MenuAction.changePassword,
                child: Row(
                  children: [
                    Icon(Icons.lock),
                    SizedBox(width: 12),
                    Text('Change Password'),
                  ],
                ),
              ),
              const PopupMenuItem<_MenuAction>(
                value: _MenuAction.logout,
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Text(
                initials,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: destinations,
      ),
    );
  }
}
