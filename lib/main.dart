import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patentinvest_beta_sdk/patentinvest_beta_sdk.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase only on mobile (not available on Windows desktop)
  if (Platform.isIOS || Platform.isAndroid) {
    try {
      // Dynamic import to avoid Windows compilation issues
      // Firebase init happens here on mobile only
    } catch (_) {}
  }

  final betaUrl = await BetaStorage.getApiBaseUrl() ?? 'http://72.60.168.119:8891';

  // Show beta onboarding on first launch; otherwise initialise SDK normally.
  final hasSeenBeta = await BetaStorage.hasSeenBetaPrompt();
  if (!hasSeenBeta) {
    runApp(_BetaSetupGate(apiBaseUrl: betaUrl, appId: 'phantom'));
    return;
  }

  await BetaSDK.initialize(apiBaseUrl: betaUrl, appId: 'phantom');
  runApp(BetaSDK.wrapApp(const ProviderScope(child: PhantomApp())));
}

/// One-time beta tester setup screen shown on first launch.
class _BetaSetupGate extends StatelessWidget {
  const _BetaSetupGate({required this.apiBaseUrl, required this.appId});
  final String apiBaseUrl;
  final String appId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: BetaTesterIdScreen(
        apiBaseUrl: apiBaseUrl,
        appId: appId,
        onComplete: (testerId) async {
          if (testerId != null) {
            await BetaSDK.initialize(
                apiBaseUrl: apiBaseUrl, appId: appId, userId: testerId);
          }
          runApp(BetaSDK.wrapApp(const ProviderScope(child: PhantomApp())));
        },
      ),
    );
  }
}

class PhantomApp extends ConsumerWidget {
  const PhantomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Phantom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
