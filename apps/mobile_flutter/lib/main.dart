import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/api/api_client.dart';
import 'presentation/pages/splash/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize API client
  final apiClient = ApiClient();
  await apiClient.initialize();

  // Set up authentication failure callback
  // This will trigger when token refresh fails
  apiClient.onAuthenticationFailed = () {
    print('[Main] Authentication failed, redirecting to login...');
    AppRouter.authNotifier.setLoggedIn(false);
  };

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F1B22),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: GachitoreApp(),
    ),
  );
}

class GachitoreApp extends StatefulWidget {
  const GachitoreApp({super.key});

  @override
  State<GachitoreApp> createState() => _GachitoreAppState();
}

class _GachitoreAppState extends State<GachitoreApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _hideSplashAfterDelay();
  }

  Future<void> _hideSplashAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash first, then router
    if (_showSplash) {
      return MaterialApp(
        title: 'ガチトレ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashPage(),
      );
    }

    return MaterialApp.router(
      title: 'ガチトレ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
