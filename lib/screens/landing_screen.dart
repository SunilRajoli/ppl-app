import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/providers/auth_provider.dart';
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
  bool _termsOpen = false;
  bool _privacyOpen = false;

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

  void _closeAllModals() {
    setState(() {
      _contactOpen = false;
      _termsOpen = false;
      _privacyOpen = false;
    });
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

    final anyModalOpen = _contactOpen || _termsOpen || _privacyOpen;

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
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fade,
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                scrollbars: false,
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
                      onOpenTerms: () => setState(() => _termsOpen = true),
                      onOpenPrivacy: () => setState(() => _privacyOpen = true),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (anyModalOpen)
            Positioned.fill(
              child: _ModalScrim(
                onClose: _closeAllModals,
                child: SafeArea(
                  top: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _contactOpen
                          ? _ContactModal(onClose: _closeAllModals, key: const ValueKey('contact'))
                          : _termsOpen
                              ? TermsModalSheet(onClose: _closeAllModals, key: const ValueKey('terms'))
                              : PrivacyModalSheet(onClose: _closeAllModals, key: const ValueKey('privacy')),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
            'Where Student Projects Meet Real Investors',
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
            "The Premier Project League (PPL) is India's first platform connecting students, colleges, and investors to turn academic projects into startup opportunities.",
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Column(
            children: const [
              _InfoCard(
                icon: Icons.school,
                title: 'Entrepreneurial Skills',
                description: 'Learn through our comprehensive Startup Course.',
              ),
              SizedBox(height: 12),
              _InfoCard(
                icon: Icons.emoji_events,
                title: 'Compete & Excel',
                description: 'Challenge top projects from other colleges.',
              ),
              SizedBox(height: 12),
              _InfoCard(
                icon: Icons.trending_up,
                title: 'Pitch to Investors',
                description: 'Present to industry experts and investors.',
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

    // Replaced emojis with icons to avoid missing glyph warnings on web
    final items = const [
      (Icons.attach_money, 'Potential Investments', 'Funding to kickstart your startup.'),
      (Icons.handshake, 'Mentorship', 'Guidance from experienced founders and experts.'),
      (Icons.apartment, 'Incubation', 'Access to incubation and accelerator programs.'),
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
                          Icon(i.$1, color: Colors.white, size: 28),
                          const SizedBox(height: 6),
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
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const _Footer({
    required this.onContactTap,
    required this.onAnchorTap,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _FooterTextButton('Terms', onOpenTerms),
                    _FooterTextButton('Privacy', onOpenPrivacy),
                    _FooterTextButton('Contact', onContactTap), // added beside Privacy
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
            Container(
              height: 1,
              color: divider,
              margin: const EdgeInsets.symmetric(vertical: 18),
            ),
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

class _FooterTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterTextButton(this.label, this.onTap);

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

/* -------------------------- helpers -------------------------- */

Future<void> _launchUri(String uri) async {
  final url = Uri.parse(uri);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/* ------------------------- MODAL HOST ------------------------ */

class _ModalScrim extends StatelessWidget {
  final Widget child;
  final VoidCallback onClose;
  const _ModalScrim({required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(onTap: onClose),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ],
      ),
    );
  }
}

/* ------------------------- CONTACT MODAL --------------------- */

class _ContactModal extends StatefulWidget {
  final VoidCallback onClose;
  const _ContactModal({required this.onClose, super.key});

  @override
  State<_ContactModal> createState() => _ContactModalState();
}

class _ContactModalState extends State<_ContactModal> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();

  bool _sending = false;
  bool? _ok;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _emailV(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim()) ? 'Enter a valid email' : null);

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    setState(() {
      _sending = true;
      _ok = null;
    });

    try {
      // TODO: wire to your backend/email provider
      await Future.delayed(const Duration(milliseconds: 900));
      setState(() => _ok = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent!')),
        );
      }
      widget.onClose();
    } catch (_) {
      setState(() => _ok = false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('contact-sheet'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 640),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Get In Touch', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            padding: const EdgeInsets.all(12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact Information', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('📧 admin@theppl.in'),
                Text('📞 +91 8688272429'),
                Text('📍 Gajuwaka, Visakhapatnam, India'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: _req,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email Address'),
                        validator: _emailV,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: _req,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _message,
                  decoration: const InputDecoration(labelText: 'Message'),
                  validator: _req,
                  maxLines: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _sending ? null : widget.onClose,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  child: Text(_sending ? 'Sending...' : 'Send'),
                ),
              ),
            ],
          ),
          if (_ok == false) ...[
            const SizedBox(height: 8),
            const Text('Failed to send. Please try again.', style: TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}

/* ------------------------- TERMS MODAL ----------------------- */

class TermsModalSheet extends StatelessWidget {
  final VoidCallback onClose;
  const TermsModalSheet({required this.onClose, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = DateTime.now().year;
    final lastUpdated = _formatToday();

    return Container(
      key: const ValueKey('terms-sheet'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.scale, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Terms & Conditions',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // BODY — scrollable and height-limited to avoid overflow on small screens
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.70,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to theppl.in. By accessing or using our website, you agree to be bound by these Terms and Conditions.',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _h3(context, 'Definitions'),
                      _p(
                          '“Website” refers to theppl.in. “We”, “Us”, and “Our” refer to the owners and administrators of the website. “User” refers to any person accessing or using our website.'),
                      _h3(context, 'Use of the Website'),
                      _p(
                          'Users agree to use the website only for lawful purposes and in a manner that does not infringe the rights of, restrict, or inhibit anyone else’s use of the site. Unauthorized access, data extraction, or misuse of site content is strictly prohibited.'),
                      _h3(context, 'Account & Registration'),
                      _p(
                          'Users are responsible for maintaining confidentiality of login information and for all activities under their account. Users must be at least 13 years old to register or use this website.'),
                      _h3(context, 'Intellectual Property'),
                      _p(
                          'All content, graphics, logos, and materials on this site are owned by theppl.in unless otherwise stated. You may not reproduce, distribute, or exploit any material without written consent.'),
                      _h3(context, 'Payments & Refunds'),
                      _p(
                          'Payments made through the site (if applicable) are subject to the stated pricing and refund policies. Refunds, if applicable, will follow our Refund Policy guidelines.'),
                      _h3(context, 'Limitation of Liability'),
                      _p(
                          'We do not guarantee that the website will be error-free or available at all times. To the maximum extent permitted by law, we are not liable for any damages resulting from the use of our site.'),
                      _h3(context, 'Indemnification'),
                      _p(
                          'Users agree to indemnify and hold harmless theppl.in and its team from any claims, damages, or expenses arising from misuse of the website.'),
                      _h3(context, 'Termination'),
                      _p(
                          'We reserve the right to suspend or terminate user access at any time without notice if we believe the terms have been violated.'),
                      _h3(context, 'Governing Law'),
                      _p('These terms are governed by the laws of India.'),
                      _h3(context, 'Changes to the Terms'),
                      _p(
                          'We may revise these Terms from time to time. Your continued use of the Website means you accept the changes. Please check this page frequently for updates.'),
                      _h3(context, 'Contact Us'),
                      _p.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Questions? Email '),
                          WidgetSpan(
                            child: InkWell(
                              onTap: () => _launchUri('mailto:support@theppl.in'),
                              child: Text('support@theppl.in',
                                  style: TextStyle(color: theme.colorScheme.primary)),
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text('Last updated: $lastUpdated', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '© $year Premier Project League — Terms and Conditions',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------ PRIVACY MODAL ---------------------- */

class PrivacyModalSheet extends StatelessWidget {
  final VoidCallback onClose;
  const PrivacyModalSheet({required this.onClose, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = DateTime.now().year;
    final lastUpdated = _formatToday();

    return Container(
      key: const ValueKey('privacy-sheet'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.shield, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Privacy Policy',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // BODY — scrollable and height-limited
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.70,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'At theppl.in, we value your privacy. This policy explains how we collect, use, and safeguard your information.',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _h3(context, 'Information We Collect'),
                      _p(
                          'We may collect personal information (name, email) and non-personal data (browser type, IP, usage statistics via cookies).'),
                      _h3(context, 'How We Use Information'),
                      _p(
                          'To provide and improve services, communicate updates, process registrations, and respond to inquiries.'),
                      _h3(context, 'Cookies'),
                      _p(
                          'We use cookies to enhance experience and for analytics. You can disable cookies in your browser; some features may not work properly.'),
                      _h3(context, 'Sharing & Disclosure'),
                      _p(
                          'We don’t sell personal data. We may share limited information with trusted providers (hosting, payments) only as necessary to operate the site.'),
                      _h3(context, 'Data Security'),
                      _p(
                          'We apply reasonable safeguards but cannot guarantee absolute security of electronic transmissions.'),
                      _h3(context, 'Your Rights'),
                      _p('You may request access, correction, or deletion of your data by contacting us.'),
                      _h3(context, 'Children’s Privacy'),
                      _p('Our services are not directed to children under 13.'),
                      _h3(context, 'Changes to This Policy'),
                      _p(
                          'We may update this policy. Continued use means you accept the changes — please check this page regularly.'),
                      _h3(context, 'Contact Us'),
                      _p.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Email '),
                          WidgetSpan(
                            child: InkWell(
                              onTap: () => _launchUri('mailto:privacy@theppl.in'),
                              child: Text('privacy@theppl.in',
                                  style: TextStyle(color: theme.colorScheme.primary)),
                            ),
                          ),
                          const TextSpan(text: ' for any privacy questions.'),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text('Last updated: $lastUpdated', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '© $year Premier Project League — Privacy Policy',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------- SHARED TEXT HELPERS ----------------- */

Widget _h3(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 8.0, bottom: 4),
    child: Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
  );
}

class _p extends StatelessWidget {
  final String? text;
  final InlineSpan? rich;
  const _p([this.text]) : rich = null;
  const _p.rich(this.rich) : text = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rich != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RichText(text: rich!, textAlign: TextAlign.start),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text ?? '', style: theme.textTheme.bodyMedium),
    );
  }
}

String _formatToday() {
  final now = DateTime.now();
  const months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}
