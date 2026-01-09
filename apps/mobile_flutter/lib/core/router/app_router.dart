import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/setup/setup_page.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/food/food_page.dart';
import '../../presentation/pages/muscle/muscle_page.dart';
import '../../presentation/pages/board/board_page.dart';
import '../../presentation/pages/settings/settings_page.dart';
import '../../presentation/pages/support/privacy_policy_page.dart';
import '../../presentation/pages/support/support_contact_page.dart';
import '../../presentation/pages/support/support_help_page.dart';
import '../../presentation/pages/support/terms_of_service_page.dart';
import '../constants/app_colors.dart';
import '../api/api_client.dart';
import '../auth/secure_token_storage.dart';
import '../onboarding/onboarding_progress_storage.dart';

/// Auth state notifier for GoRouter
class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  bool _hasChecked = false;
  bool get hasChecked => _hasChecked;

  Future<void>? _checkFuture;

  Future<void> checkAuthStatus() {
    _checkFuture ??= _checkAuthStatusInternal().whenComplete(() {
      _checkFuture = null;
    });
    return _checkFuture!;
  }

  Future<void> _checkAuthStatusInternal() async {
    if (kDebugMode) {
      debugPrint('[Auth] checkAuthStatus start');
    }

    // Migrate tokens from SharedPreferences to SecureStorage (one-time)
    await SecureTokenStorage.migrateFromSharedPreferences();

    // access_token が期限切れでも refresh_token があれば復元できるようにする
    // NOTE: 起動時のネットワーク不調でGoRouterが固まらないようにタイムアウトを入れる
    final ok = await ApiClient()
        .ensureValidSession()
        .timeout(const Duration(seconds: 5), onTimeout: () => false);

    if (ok) {
      final token = await SecureTokenStorage.getAccessToken();
      _isLoggedIn = token != null && token.isNotEmpty;
    } else {
      _isLoggedIn = false;
    }

    if (!_isLoggedIn) {
      OnboardingProgressStorage.resetMemory();
    }

    _hasChecked = true;
    if (kDebugMode) {
      debugPrint('[Auth] checkAuthStatus done ok=$ok isLoggedIn=$_isLoggedIn');
    }
    notifyListeners();
  }

  void setLoggedIn(bool value) {
    _isLoggedIn = value;
    _hasChecked = true;
    if (!value) {
      OnboardingProgressStorage.resetMemory();
    }
    notifyListeners();
  }
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final authNotifier = AuthNotifier();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    // セッションが残っていればログイン画面をスキップしたいので、まず保護ルートへ
    initialLocation: '/home',
    refreshListenable: authNotifier,
    redirect: (context, state) async {
      final path = state.uri.path;

      // Login and setup pages - no redirect needed
      // NOTE: 起動直後は状態が不明なことがあるので、ここで最小限のセッション復元を行う
      if (!authNotifier.hasChecked) {
        await authNotifier.checkAuthStatus();
      }

      // ログイン済みならログイン画面はスキップ
      if (authNotifier.isLoggedIn && (path == '/login')) {
        // オンボーディング未完了なら setup に飛ばす
        final completed = await OnboardingProgressStorage.getCompleted();
        return completed ? '/home' : '/setup';
      }

      // 未ログインなら保護ルートはログインへ
      if (!authNotifier.isLoggedIn && path != '/login' && path != '/setup') {
        return '/login';
      }

      // ログイン済みでオンボーディング未完了なら、/setup 以外へ行かせない
      if (authNotifier.isLoggedIn) {
        final completed = await OnboardingProgressStorage.getCompleted();
        if (!completed && path != '/setup') {
          return '/setup';
        }
        // 逆に完了済みなら /setup へ戻さない
        if (completed && path == '/setup') {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupPage(),
      ),

      // Support routes (open from settings, hide bottom navigation)
      GoRoute(
        path: '/support/help',
        builder: (context, state) => const SupportHelpPage(),
      ),
      GoRoute(
        path: '/support/contact',
        builder: (context, state) => const SupportContactPage(),
      ),
      GoRoute(
        path: '/support/privacy',
        builder: (context, state) => const PrivacyPolicyPage(),
      ),
      GoRoute(
        path: '/support/terms',
        builder: (context, state) => const TermsOfServicePage(),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: '/food',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FoodPage(),
            ),
          ),
          GoRoute(
            path: '/muscle',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MusclePage(),
            ),
          ),
          GoRoute(
            path: '/board',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BoardPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
}

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _routes = ['/home', '/food', '/muscle', '/board', '/settings'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateIndex();
  }

  void _updateIndex() {
    final location = GoRouterState.of(context).uri.path;
    final index = _routes.indexOf(location);
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  void _onTap(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      context.go(_routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSub,
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'ホーム'),
                _buildNavItem(1, Icons.restaurant_outlined, Icons.restaurant, '食事'),
                _buildNavItem(2, Icons.fitness_center_outlined, Icons.fitness_center, 'トレーニング'),
                _buildNavItem(3, Icons.forum_outlined, Icons.forum, '掲示板'),
                _buildNavItem(4, Icons.settings_outlined, Icons.settings, '設定'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
