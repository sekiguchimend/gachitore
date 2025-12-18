import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/api/api_client.dart';
import 'presentation/pages/splash/splash_page.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('[FlutterError] ${details.exceptionAsString()}');
        debugPrintStack(stackTrace: details.stack);
      }
    };

    runApp(
      const ProviderScope(
        child: GachitoreApp(),
      ),
    );

    // 起動処理は初回描画をブロックしない（起動画面で止まる根本原因を潰す）
    Future.microtask(_bootstrapAsync);
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('[ZoneError] $error');
      debugPrintStack(stackTrace: stack);
    }
  });
}

Future<void> _bootstrapAsync() async {
  try {
    if (kDebugMode) {
      debugPrint('[Bootstrap] start');
    }
    final apiClient = ApiClient();
    if (kDebugMode) {
      debugPrint('[Bootstrap] ApiClient created');
    }
    await apiClient.initialize();
    if (kDebugMode) {
      debugPrint('[Bootstrap] ApiClient.initialize done');
    }

    apiClient.onAuthenticationFailed = () {
      if (kDebugMode) {
        debugPrint('[Main] Authentication failed, redirecting to login...');
      }
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
    if (kDebugMode) {
      debugPrint('[Bootstrap] orientations set');
    }

    // 認証チェックはハング防止で上限を入れる（失敗してもUIは進める）
    await AppRouter.authNotifier
        .checkAuthStatus()
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    if (kDebugMode) {
      debugPrint('[Bootstrap] checkAuthStatus done');
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[BootstrapError] $e');
      debugPrintStack(stackTrace: st);
    }
  }
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
    if (kDebugMode) {
      debugPrint('[GachitoreApp] initState');
    }
    _hideSplashAfterDelay();
  }

  Future<void> _hideSplashAfterDelay() async {
    if (kDebugMode) {
      debugPrint('[GachitoreApp] splash delay start');
    }
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      if (kDebugMode) {
        debugPrint('[GachitoreApp] splash -> router');
      }
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
