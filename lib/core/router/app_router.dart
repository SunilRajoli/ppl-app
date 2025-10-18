// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/app_initializer.dart';
import '../../screens/landing_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/role_selection_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/auth/change_password_screen.dart';
import '../../screens/competitions/public_competitions_screen.dart';
import '../../screens/competitions/competition_details_screen.dart';
import '../../screens/competitions/create_competition_screen.dart';
import '../../screens/competitions/competition_leaderboard_screen.dart';
import '../../screens/admin/admin_hub_screen.dart';
import '../../screens/admin/role_list_screen.dart';
import '../../screens/competitions/competition_register_screen.dart';
import '../../screens/competitions/competition_submit_screen.dart';
import '../../screens/main/main_nav_screen.dart' as main_nav;
import '../../screens/main/profile_screen.dart';
import '../../screens/contact/contact_screen.dart';
import '../../screens/contacts/contact_history_screen.dart';
import '../../screens/competitions/my_submissions_screen.dart';
import '../../screens/auth/email_verification_notice_screen.dart';
import '../../screens/auth/verify_email_screen.dart';
import '../../screens/auth/oauth_callback_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: <RouteBase>[
      GoRoute(path: '/splash', builder: (context, state) => const AppInitializer()),
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/roles', builder: (context, state) => const RoleSelectionScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
          return LoginScreen(role: extra?['role'] as String?);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
          final role = extra?['role'] as String?;
          
          // Prevent admin users from accessing register screen
          if (role == 'admin') {
            // Redirect admin users to login instead
            return LoginScreen(role: role);
          }
          
          return RegisterScreen(role: role);
        },
      ),
      // ✅ NEW: Email verification notice (after registration)
      GoRoute(
        path: '/verify-email-sent',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return EmailVerificationNoticeScreen(initialEmail: email);
        },
      ),

      // ✅ NEW: Verify-email endpoint (consumes ?token=)
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return VerifyEmailScreen(token: token);
        },
      ),

      // ✅ NEW: OAuth callback endpoint (consumes ?token= & ?provider=)
      GoRoute(
        path: '/oauth-callback',
        builder: (context, state) => const OAuthCallbackScreen(),
      ),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(path: '/reset-password/:token', builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      // Main areas
      GoRoute(
        path: '/main',
        builder: (context, state) => main_nav.MainNavScreen(initialTab: state.uri.queryParameters['tab'] ?? 'dashboard'),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => main_nav.MainNavScreen(initialTab: state.uri.queryParameters['tab'] ?? 'dashboard'),
      ),

      // Public competitions index
      GoRoute(path: '/competitions', builder: (context, state) => const PublicCompetitionsScreen()),
      
      // Courses page
      GoRoute(path: '/courses', builder: (context, state) => const LandingScreen(embedded: true)), // Placeholder for courses
      
      // Contact page
      GoRoute(path: '/contact', builder: (context, state) => const LandingScreen(embedded: true)), // Placeholder for contact
      
      // About page
      GoRoute(path: '/about', builder: (context, state) => const LandingScreen(embedded: true)), // Placeholder for about

      // ---- Specific competition routes FIRST ----
      GoRoute(path: '/competition/create', builder: (context, state) => const CreateCompetitionScreen()),
      GoRoute(
        path: '/competition/:id/edit',
        builder: (context, state) => const CreateCompetitionScreen(),
      ),
      GoRoute(
        path: '/competition/:id/register',
        builder: (context, state) => CompetitionRegisterScreen(
          competitionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        name: 'competition-submit',
        path: '/competition/:id/submit',
        builder: (context, state) => CompetitionSubmitScreen(
          competitionId: state.pathParameters['id'],
          competitionTitle: (state.extra is Map) ? (state.extra as Map)['title'] as String? : null,
          competitionMeta: (state.extra is Map) ? (state.extra as Map)['meta'] as Map<String, dynamic>? : null,
        ),
      ),
      // Leaderboard uses plural '/competitions'
      GoRoute(
        path: '/competition/:id/leaderboard',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CompetitionLeaderboardScreen(competitionId: id);
        },
      ),

      // ---- My Submissions (User) ----
      GoRoute(
        path: '/me/submissions',
        builder: (context, state) => const MySubmissionsScreen(),
      ),

      // ---- Admin: Manage Submissions for a Competition ----
      // Keep before the generic '/competition/:id' catch-all
      GoRoute(
        path: '/admin/competition/:id/submissions',
        builder: (context, state) => MySubmissionsScreen(
          competitionId: state.pathParameters['id'],
          competitionTitle: (state.extra is Map)
              ? (state.extra as Map)['competitionTitle'] as String?
              : null,
        ),
      ),

      // ---- Catch-all details LAST ----
      GoRoute(
        path: '/competition/:id',
        builder: (context, state) => CompetitionDetailsScreen(
          competitionId: state.pathParameters['id']!,
        ),
      ),

      // Admin utilities
      GoRoute(path: '/admin/hub', builder: (context, state) => const AdminHubScreen()),
      GoRoute(
        path: '/admin/roles/:role',
        builder: (context, state) => RoleListScreen(role: state.pathParameters['role'] ?? 'student'),
      ),
      
      // Profile routes
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) => ProfileScreen(
          userId: state.pathParameters['id'],
        ),
      ),
      
      // Contact route
      GoRoute(
        path: '/contact/:id',
        builder: (context, state) {
          final extra = state.extra is Map<String, dynamic> 
              ? state.extra as Map<String, dynamic> 
              : <String, dynamic>{};
          return ContactScreen(
            userId: state.pathParameters['id']!,
            userName: extra['userName'] as String?,
            userRole: extra['userRole'] as String?,
          );
        },
      ),


      // Contact history route
      GoRoute(
        path: '/contact-history',
        builder: (context, state) => const ContactHistoryScreen(),
      ),
      
      // 404 - Catch all route
      GoRoute(
        path: '/:path(.*)',
        builder: (context, state) => const _NotFoundScreen(),
      ),
    ],
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '404 - Page Not Found',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
