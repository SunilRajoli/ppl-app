// lib/widgets/global_top_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import 'custom_widgets.dart'; // ThemeToggle

class NavLink {
  final String href; // "#about" or "/competitions"
  final String label; // "About"
  final String type; // "scroll" | "route"
  const NavLink({required this.href, required this.label, required this.type});
}

class GlobalTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String brand;
  final List<NavLink> navLinks; // kept for compatibility (unused in mobile-only)
  final bool showRegister; // show the Sign Up button before login
  final bool isOnLanding; // true when current route is "/"
  final void Function(String id)? onScrollTo; // e.g., "about", "why-ppl"
  final VoidCallback onOpenContact;

  const GlobalTopBar({
    super.key,
    this.brand = "PPL",
    required this.navLinks,
    required this.showRegister,
    required this.isOnLanding,
    required this.onScrollTo,
    required this.onOpenContact,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  String _homeHref(bool isAuthed, bool isAdmin) {
    if (!isAuthed) return '/';
    return isAdmin ? '/admin?tab=dashboard' : '/main?tab=dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final isAuthed = auth.isAuthenticated;
    final isAdmin = (auth.user?.role ?? '').toLowerCase() == 'admin';

    return AppBar(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: theme.colorScheme.surface.withOpacity(0.90),
      shadowColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      shape: Border(
        bottom: BorderSide(
          width: 0.6,
          color: AppColors.borderOf(context),
        ),
      ),
      leadingWidth: 140,
      leading: InkWell(
        onTap: () => context.go(_homeHref(isAuthed, isAdmin)),
        child: Row(
          children: [
            const SizedBox(width: 12),
            SizedBox(
              height: 26,
              width: 26,
              child: Image.asset(
                'assets/logo.png', // ensure declared in pubspec.yaml
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.star_rounded, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              brand,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),

      // No desktop title; mobile keeps right-side actions only
      title: const SizedBox.shrink(),
      titleSpacing: 0,

      actions: [
        const ThemeToggle(),
        const SizedBox(width: 6),

        if (!isAuthed && showRegister)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: () => context.go('/roles'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Sign Up'),
            ),
          ),

        IconButton(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu),
          onPressed: () => _openMobileMenuSheet(
            context: context,
            isOnLanding: isOnLanding,
            onScrollTo: onScrollTo,
            onOpenContact: onOpenContact,
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  void _openMobileMenuSheet({
    required BuildContext context,
    required bool isOnLanding,
    required void Function(String id)? onScrollTo,
    required VoidCallback onOpenContact,
  }) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 44,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              ListTile(
                title: const Text('About'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (isOnLanding && onScrollTo != null) {
                    onScrollTo('about');
                  } else {
                    GoRouter.of(context).go('/#about');
                  }
                },
              ),
              ListTile(
                title: const Text('Why PPL'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (isOnLanding && onScrollTo != null) {
                    onScrollTo('why-ppl');
                  } else {
                    GoRouter.of(context).go('/#why-ppl');
                  }
                },
              ),
              ListTile(
                title: const Text('Contact'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Future.delayed(const Duration(milliseconds: 120), onOpenContact);
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Login'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  GoRouter.of(context).go('/login');
                },
              ),
              ListTile(
                title: const Text('Sign Up'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  GoRouter.of(context).go('/roles');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
