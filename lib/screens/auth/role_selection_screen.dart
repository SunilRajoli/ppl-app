import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Role Selection (mobile-friendly, smart back behavior)
/// - Shows 4 roles: student, hiring team, investor, admin
/// - "Skip" goes to /login
/// - Back button only shows when a previous page exists
/// - System back is intercepted: pop if possible, otherwise go to '/'
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedRole; // 'student' | 'hiring' | 'investor' | 'admin'
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    // Fallback when there's no history (e.g., this screen opened via .go)
    context.go('/'); // change to '/login' if you prefer
  }

  void _onContinue() {
    if (_selectedRole == null) return;
    // Pass the chosen role into /login. Your login screen can read it via GoRouter's 'extra'.
    context.push('/login', extra: {'role': _selectedRole});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = GoRouter.of(context).canPop() || Navigator.of(context).canPop();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: canPop,
          leading: canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBack,
                  tooltip: 'Back',
                )
              : null,
          title: const Text('Choose Role'),
          actions: [
            // ❌ Skip button commented out
            // TextButton(
            //   onPressed: () => context.push('/login'),
            //   child: const Text('Skip'),
            // ),
          ],
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  scrollbars: false, // <-- hide Flutter scrollbars
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Choose your role',
                                  style: theme.textTheme.headlineMedium),
                              Text("We'll tailor the experience for you",
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Pick a role to get relevant actions, dashboards, and quick-start tips. '
                            'You can switch later in your profile settings.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Roles (4)
                      _buildRoleCard(
                        theme: theme,
                        role: 'student',
                        icon: Icons.school,
                        title: 'Student',
                        description:
                            'Showcase projects, join competitions & learn by doing.',
                      ),
                      const SizedBox(height: 16),

                      _buildRoleCard(
                        theme: theme,
                        role: 'hiring',
                        icon: Icons.badge_outlined,
                        title: 'Hiring Team',
                        description:
                            'Discover candidates, post roles, and evaluate project work.',
                      ),
                      const SizedBox(height: 16),

                      _buildRoleCard(
                        theme: theme,
                        role: 'investor',
                        icon: Icons.trending_up,
                        title: 'Investor',
                        description:
                            'Track top teams, review pitches, and connect for deals.',
                      ),
                      const SizedBox(height: 16),

                      _buildRoleCard(
                        theme: theme,
                        role: 'admin',
                        icon: Icons.shield_outlined,
                        title: 'Admin',
                        description:
                            'Create & manage competitions, teams, and results.',
                      ),

                      const SizedBox(height: 32),

                      // Continue Button
                      ElevatedButton(
                        onPressed: _selectedRole != null ? _onContinue : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _selectedRole != null
                              ? 'Continue as ${_selectedRole!.toUpperCase()}'
                              : 'Select a role to continue',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required ThemeData theme,
    required String role,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedRole == role;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? theme.colorScheme.primary.withOpacity(0.08)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedRole = role),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.iconTheme.color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: isSelected ? theme.colorScheme.primary : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Selected',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
