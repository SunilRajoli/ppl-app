import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Optional: transparent system bars for a clean UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const PPLApp());
}

class PPLApp extends StatelessWidget {
  const PPLApp({super.key});

  // Helper: apply Inter font using Google Fonts
  ThemeData _withInter(ThemeData base) {
    final interTextTheme = GoogleFonts.interTextTheme(base.textTheme);
    final interPrimaryTextTheme = GoogleFonts.interTextTheme(base.primaryTextTheme);

    return base.copyWith(
      useMaterial3: true,
      textTheme: interTextTheme,
      primaryTextTheme: interPrimaryTextTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: GoogleFonts.inter(
          textStyle: base.appBarTheme.titleTextStyle ?? base.textTheme.titleLarge,
        ),
        toolbarTextStyle: GoogleFonts.inter(
          textStyle: base.appBarTheme.toolbarTextStyle ?? base.textTheme.titleMedium,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Apply Inter font to both theme variants
          final light = _withInter(AppTheme.lightTheme);
          final dark = _withInter(AppTheme.darkTheme);

          return MaterialApp.router(
            title: 'Premier Project League',
            debugShowCheckedModeBanner: false,
            theme: light,
            darkTheme: dark,
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.router,
            scrollBehavior: const _NoGlowScrollBehavior(),
          );
        },
      ),
    );
  }
}

/// Optional — removes overscroll glow on scrollables
class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
