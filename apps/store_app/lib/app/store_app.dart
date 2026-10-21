import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/login_screen.dart';
import '../presentation/dashboard_screen.dart';
import '../presentation/garment_editor_screen.dart';
import '../presentation/garment_detail_screen.dart';
import '../presentation/customer_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final unlocked = ref.watch(accessProvider);
  final router = GoRouter(
    initialLocation: unlocked ? '/' : '/login',
    redirect: (context, state) =>
        !unlocked && state.uri.path != '/login' ? '/login' : null,
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(
        path: '/garment/new',
        builder: (_, _) => const GarmentEditorScreen(),
      ),
      GoRoute(
        path: '/garment/:id/edit',
        builder: (_, s) => GarmentEditorScreen(id: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/garment/:id',
        builder: (_, s) => GarmentDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/customer', builder: (_, _) => const CustomerScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('بازگشت به خانه'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6554c0)),
  fontFamily: 'Vazirmatn',
  scaffoldBackgroundColor: const Color(0xfff7f7fa),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xfff7f7fa),
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    alignLabelWithHint: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);

class StoreApp extends ConsumerWidget {
  const StoreApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'بوتیک',
    debugShowCheckedModeBanner: false,
    locale: const Locale('fa', 'IR'),
    supportedLocales: const [Locale('fa', 'IR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: buildTheme(),
    routerConfig: ref.watch(routerProvider),
  );
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: const Locale('fa', 'IR'),
    supportedLocales: const [Locale('fa', 'IR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'باز کردن اطلاعات محلی ممکن نشد.\nفضای دستگاه و نسخه برنامه را بررسی کنید و دوباره برنامه را باز کنید.\nبرای حفظ اطلاعات، داده‌ها را پاک نکنید.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
