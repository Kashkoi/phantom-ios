import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../platform/platform_utils.dart';
import '../../features/home/home_screen.dart';
import '../../features/media_browser/media_browser_screen.dart';
import '../../features/caption_preview/caption_preview_screen.dart';
import '../../features/snapchat_post/snap_post_screen.dart';
import '../../features/engagement/engagement_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/agent_control/agent_control_screen.dart';
import '../../features/connections/connections_screen.dart';
import '../../features/media_sources/media_sources_screen.dart';

final _rootNavKey = GlobalKey<NavigatorState>();
final _shellNavKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isLoginRoute = state.matchedLocation == '/login';
      final isBiometric = authState.status == AuthStatus.biometricRequired;

      if (isBiometric && state.matchedLocation != '/biometric') return '/biometric';
      if (!isAuth && !isLoginRoute && !isBiometric) return '/login';
      if (isAuth && isLoginRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const _LoginScreen()),
      GoRoute(path: '/biometric', builder: (_, __) => const _BiometricScreen()),

      // Main shell with adaptive nav (rail on desktop, bar on mobile)
      ShellRoute(
        navigatorKey: _shellNavKey,
        builder: (_, __, child) => _AdaptiveShell(child: child),
        routes: [
          GoRoute(path: '/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen())),
          GoRoute(path: '/connections',
            pageBuilder: (_, __) => const NoTransitionPage(child: ConnectionsScreen())),
          GoRoute(path: '/engagement',
            pageBuilder: (_, __) => const NoTransitionPage(child: EngagementScreen())),
          GoRoute(path: '/analytics',
            pageBuilder: (_, __) => const NoTransitionPage(child: AnalyticsScreen())),
          GoRoute(path: '/settings',
            pageBuilder: (_, __) => const NoTransitionPage(child: SettingsScreen())),
        ],
      ),

      // Full-screen routes
      GoRoute(path: '/media-browser', builder: (_, __) => const MediaBrowserScreen()),
      GoRoute(path: '/caption-preview',
        builder: (_, state) => CaptionPreviewScreen(args: state.extra as Map<String, dynamic>?)),
      GoRoute(path: '/snap-post', builder: (_, __) => const SnapPostScreen()),
      GoRoute(path: '/agent-control', builder: (_, __) => const AgentControlScreen()),
      GoRoute(path: '/media-sources', builder: (_, __) => const MediaSourcesScreen()),
    ],
  );
});

// ── Adaptive Shell ──────────────────────────────────────────────────

class _AdaptiveShell extends StatelessWidget {
  final Widget child;
  const _AdaptiveShell({required this.child});

  static const _tabs = ['/home', '/connections', '/engagement', '/analytics', '/settings'];
  static const _icons = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.link_outlined, Icons.link, 'Connect'),
    (Icons.forum_outlined, Icons.forum, 'Engage'),
    (Icons.insights_outlined, Icons.insights, 'Analytics'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexOf(location).clamp(0, _tabs.length - 1);
    final wide = MediaQuery.of(context).size.width > 800;

    if (wide) {
      // Desktop: NavigationRail on the left
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(_tabs[i]),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFF7B2FF7)],
                  ).createShader(b),
                  child: const Text('P', style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white,
                  )),
                ),
              ),
              destinations: _icons.map((e) => NavigationRailDestination(
                icon: Icon(e.$1), selectedIcon: Icon(e.$2), label: Text(e.$3),
              )).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile: BottomNavigationBar
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: _icons.map((e) => NavigationDestination(
          icon: Icon(e.$1), selectedIcon: Icon(e.$2), label: e.$3,
        )).toList(),
      ),
    );
  }
}

// ── Auth Screens ────────────────────────────────────────────────────

class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen();
  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Color(0xFF00D2FF), Color(0xFF7B2FF7)],
                    ).createShader(b),
                    child: const Text('PHANTOM', style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white,
                    )),
                  ),
                  const SizedBox(height: 8),
                  Text('Social Media Agent',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).login(_userCtrl.text, _passCtrl.text);
    if (mounted) setState(() => _loading = false);
  }
}

class _BiometricScreen extends ConsumerWidget {
  const _BiometricScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: Color(0xFF7B2FF7)),
            const SizedBox(height: 24),
            const Text('Authenticate to Continue', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).authenticateWithBiometrics(),
              icon: Icon(isDesktop ? Icons.lock_open : Icons.face),
              label: Text(isDesktop ? 'Unlock' : 'Use Face ID'),
            ),
          ],
        ),
      ),
    );
  }
}
