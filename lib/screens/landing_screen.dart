import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/global_top_bar.dart';

class LandingScreen extends StatefulWidget {
  final bool embedded;
  const LandingScreen({super.key, this.embedded = false});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  final ScrollController _scroll = ScrollController();
  final aboutKey = GlobalKey();
  final howItWorksKey = GlobalKey();
  final courseKey = GlobalKey();
  final whyPplKey = GlobalKey();

  bool _contactOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  void _scrollToById(String id) {
    switch (id) {
      case 'about':
        _scrollTo(aboutKey);
        break;
      case 'how-it-works':
        _scrollTo(howItWorksKey);
        break;
      case 'course':
        _scrollTo(courseKey);
        break;
      case 'why-ppl':
        _scrollTo(whyPplKey);
        break;
      default:
        break;
    }
  }

  String _computeExploreTo(AuthProvider auth) {
    final isAuthed = auth.isAuthenticated;
    final isAdmin = (auth.user?.role ?? '').toLowerCase() == 'admin';
    if (!isAuthed) return '/competitions';
    return isAdmin ? '/admin?tab=competitions' : '/main?tab=competitions';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final exploreTo = _computeExploreTo(auth);
    final isOnLanding = GoRouterState.of(context).uri.path == '/';

    final navLinks = const [
      NavLink(href: '#about', label: 'About', type: 'scroll'),
      NavLink(href: '#how-it-works', label: 'How It Works', type: 'scroll'),
      NavLink(href: '#course', label: 'Course', type: 'scroll'),
      NavLink(href: '#why-ppl', label: 'Why PPL', type: 'scroll'),
    ];

    return Scaffold(
      appBar: widget.embedded
          ? null
          : GlobalTopBar(
              brand: 'PPL',
              navLinks: navLinks,
              showRegister: !auth.isAuthenticated,
              isOnLanding: isOnLanding,
              onScrollTo: _scrollToById,
              onOpenContact: () => setState(() => _contactOpen = true),
            ),
      body: FadeTransition(
        opacity: _fade,
        child: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            scrollbars: false, // <-- hide Flutter scrollbars
          ),
          child: SingleChildScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSection(
                  exploreTo: exploreTo,
                  showGetStarted: !auth.isAuthenticated,
                ),
                _AboutSection(key: aboutKey),
                _HowItWorksSection(key: howItWorksKey),
                _CourseSection(key: courseKey),
                _WhyPplSection(key: whyPplKey),
                const _EvaluationSection(),
                const _InvestorDaySection(),
                _Footer(
                  onContactTap: () => setState(() => _contactOpen = true),
                  onAnchorTap: _scrollToById,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: _contactOpen
          ? _ContactModal(
              onClose: () => setState(() => _contactOpen = false),
            )
          : null,
      backgroundColor: theme.colorScheme.background,
    );
  }
}

/* --------------------------- HERO (mobile-first) --------------------------- */

class _HeroSection extends StatelessWidget {
  final String exploreTo;
  final bool showGetStarted;

  const _HeroSection({
    required this.exploreTo,
    required this.showGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Turn Your College Project Into a Startup',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Compete. Learn. Pitch to investors.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.titleMedium?.color?.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(exploreTo),
                  icon: const Icon(Icons.explore),
                  label: const Text('Explore Competitions'),
                ),
              ),
              if (showGetStarted)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/roles'),
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Get Started'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/* --------------------------- ABOUT --------------------------- */

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Text('About PPL', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            "India's platform that helps students convert academic projects into real startups through a structured league—learning, competing, and pitching to investors.",
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Column(
            children: const [
              _InfoCard(
                icon: Icons.school,
                title: 'Entrepreneurial Skills',
                description: 'Practical startup course, mentors, and resources.',
              ),
              SizedBox(height: 12),
              _InfoCard(
                icon: Icons.emoji_events,
                title: 'Compete',
                description: 'Face off with top student teams across colleges.',
              ),
              SizedBox(height: 12),
              _InfoCard(
                icon: Icons.trending_up,
                title: 'Pitch Investors',
                description: 'Present to active investors on Demo & Investor Day.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------ HOW IT WORKS ----------------------- */

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      {'n': 1, 't': 'Register', 'd': 'Create your team and submit your project.'},
      {'n': 2, 't': 'Learn', 'd': 'Complete the 8-week startup course.'},
      {'n': 3, 't': 'Compete', 'd': 'Qualify through rounds and get shortlisted.'},
      {'n': 4, 't': 'Pitch Day', 'd': 'Present to investors on Investor Day.'},
    ];

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Text('How PPL Works', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 18),
          Column(
            children: steps
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _StepCard(
                        num: s['n'] as int,
                        title: s['t'] as String,
                        desc: s['d'] as String,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int num;
  final String title;
  final String desc;

  const _StepCard({required this.num, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(desc, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        Positioned(
          top: -16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 4),
              ),
              child: Center(
                child: Text(
                  '$num',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* --------------------------- COURSE -------------------------- */

class _CourseSection extends StatelessWidget {
  const _CourseSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = const [
      'Ideation & Validation',
      'Business Model',
      'MVP & Prototyping',
      'Market Research',
      'Financial Basics',
      'Pitch & Storytelling',
      'Legal Essentials',
      'Investor Prep',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Text('PPL Startup Course', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            'An 8-week program to build a validated idea, MVP, and a strong pitch.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: topics
                .map((t) => Chip(
                      label: Text(t),
                      backgroundColor: theme.colorScheme.surface,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/* --------------------------- WHY PPL ------------------------- */

class _WhyPplSection extends StatelessWidget {
  const _WhyPplSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      {
        'icon': Icons.school,
        'title': 'For Students',
        'desc':
            'Get mentorship, a real competition environment, and investor exposure.'
      },
      {
        'icon': Icons.apartment,
        'title': 'For Colleges',
        'desc':
            'Showcase innovation and build strong industry connections for your campus.'
      },
      {
        'icon': Icons.work,
        'title': 'For Investors',
        'desc': 'Early access to ambitious student teams and fresh ideas.'
      },
    ];

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Text('Why PPL?', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(c['icon'] as IconData,
                                  size: 30, color: theme.colorScheme.primary),
                              const SizedBox(height: 8),
                              Text(c['title'] as String,
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(
                                c['desc'] as String,
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- EVALUATION ------------------------ */

class _EvaluationSection extends StatelessWidget {
  const _EvaluationSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final criteria = const [
      'Innovation & Creativity',
      'Market Relevance',
      'Feasibility & Execution',
      'Scalability',
      'Impact (Social/Economic/Environmental)',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Text('Evaluation Criteria', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: criteria
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(c, style: theme.textTheme.bodyMedium)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- INVESTOR DAY ---------------------- */

class _InvestorDaySection extends StatelessWidget {
  const _InvestorDaySection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = const [
      ('💰', 'Potential Investments', 'Funding to kickstart your startup.'),
      ('🤝', 'Mentorship', 'Guidance from experienced founders and experts.'),
      ('🏛️', 'Incubation', 'Access to incubation and accelerator programs.'),
    ];

    return Container(
      color: theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 46),
          const SizedBox(height: 8),
          const Text(
            'Investor Day: The Finale',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Top teams pitch to a panel of investors, mentors, and incubators.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Column(
            children: items
                .map(
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Text(i.$1, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(i.$2,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            i.$3,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------- FOOTER ------------------------- */

class _Footer extends StatelessWidget {
  final VoidCallback onContactTap;
  final void Function(String id) onAnchorTap;
  const _Footer({required this.onContactTap, required this.onAnchorTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.dividerColor;
    final year = DateTime.now().year;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Column(
          children: [
            // Top section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand + blurb + socials (icons only)
                Row(
                  children: [
                    Icon(Icons.rocket_launch, size: 26, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Premier Project League',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Turning student projects into real startups with competitions, course, and Investor Day.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _SocialIconButton(
                      icon: const FaIcon(FontAwesomeIcons.linkedinIn, size: 18),
                      onTap: () => _launchUri('https://linkedin.com'),
                    ),
                    _SocialIconButton(
                      icon: const FaIcon(FontAwesomeIcons.github, size: 18),
                      onTap: () => _launchUri('https://github.com'),
                    ),
                    _SocialIconButton(
                      icon: const FaIcon(FontAwesomeIcons.instagram, size: 18),
                      onTap: () => _launchUri('https://instagram.com'),
                    ),
                    _SocialIconButton(
                      icon: const FaIcon(FontAwesomeIcons.youtube, size: 18),
                      onTap: () => _launchUri('https://youtube.com'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // QUICK LINKS — pill-style with icons
                Text(
                  'QUICK LINKS',
                  style: theme.textTheme.bodySmall?.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickLinkPill(
                      icon: Icons.info_outline,
                      label: 'About',
                      onTap: () => onAnchorTap('about'),
                    ),
                    _QuickLinkPill(
                      icon: Icons.schema_outlined,
                      label: 'How It Works',
                      onTap: () => onAnchorTap('how-it-works'),
                    ),
                    _QuickLinkPill(
                      icon: Icons.menu_book_outlined,
                      label: 'Course',
                      onTap: () => onAnchorTap('course'),
                    ),
                    _QuickLinkPill(
                      icon: Icons.thumb_up_alt_outlined,
                      label: 'Why PPL',
                      onTap: () => onAnchorTap('why-ppl'),
                    ),
                    _QuickLinkPill(
                      icon: Icons.emoji_events_outlined,
                      label: 'Competitions',
                      onTap: () => GoRouter.of(context).go('/competitions'),
                    ),
                    _QuickLinkPill(
                      icon: Icons.rocket_launch_outlined,
                      label: 'Get Started',
                      onTap: () => GoRouter.of(context).go('/roles'),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Legal + email (kept). No "Contact" button in bottom bar.
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _FooterRouteLink('Terms', '/terms'),
                    _FooterRouteLink('Privacy', '/privacy'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mail_outline,
                            size: 18,
                            color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _launchUri('mailto:contact@ppl.com'),
                          child: Text(
                            'contact@ppl.com',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Divider
            Container(
              height: 1,
              color: divider,
              margin: const EdgeInsets.symmetric(vertical: 18),
            ),

            // Bottom bar — centered © line only
            Center(
              child: Text(
                '© $year Premier Project League',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLinkPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              spreadRadius: 0,
              offset: const Offset(0, 1),
              color: Colors.black.withOpacity(0.04),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: IconTheme(
            data: IconThemeData(
              color: theme.colorScheme.onSurface.withOpacity(0.85),
              size: 20,
            ),
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _FooterRouteLink extends StatelessWidget {
  final String label;
  final String route;
  const _FooterRouteLink(this.label, this.route);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => GoRouter.of(context).go(route),
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

/* -------------------------- helpers -------------------------- */

Future<void> _launchUri(String uri) async {
  final url = Uri.parse(uri);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/* ------------------------- CONTACT MODAL --------------------- */

class _ContactModal extends StatelessWidget {
  final VoidCallback onClose;

  const _ContactModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black54,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
              Text('Contact', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Your Email',
                  hintText: 'you@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Message',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onClose, // TODO: wire to backend
                      child: const Text('Send'),
                    ),
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
