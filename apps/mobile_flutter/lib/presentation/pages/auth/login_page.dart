import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_router.dart';
import 'dart:async';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email format validation
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Password strength validation
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'パスワードは8文字以上で入力してください';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'パスワードには小文字を含めてください';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'パスワードには大文字を含めてください';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'パスワードには数字を含めてください';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'メールアドレスとパスワードを入力してください');
      return;
    }

    // Email format validation
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = '有効なメールアドレスを入力してください');
      return;
    }

    // Password strength validation for sign up
    if (_isSignUp) {
      final passwordError = _validatePassword(password);
      if (passwordError != null) {
        setState(() => _errorMessage = passwordError);
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final appSettings = ref.read(appSettingsServiceProvider);

      if (_isSignUp) {
        await authService.signUp(email: email, password: password);
        // GoRouterのredirectが未ログイン扱いのままだと/loginに戻されるので、
        // ログイン状態を明示的に更新する
        AppRouter.authNotifier.setLoggedIn(true);
        final pushEnabled = await appSettings.isPushNotificationsEnabled();
        if (pushEnabled) {
          unawaited(
            ref
                .read(pushNotificationServiceProvider)
                .initializeAndSync(platform: 'app'),
          );
        }
        // After sign up, navigate to setup for onboarding
        if (mounted) {
          context.go('/setup');
        }
      } else {
        await authService.signIn(email: email, password: password);
        // GoRouterのredirectが未ログイン扱いのままだと遷移できないため更新
        AppRouter.authNotifier.setLoggedIn(true);
        final pushEnabled = await appSettings.isPushNotificationsEnabled();
        if (pushEnabled) {
          unawaited(
            ref
                .read(pushNotificationServiceProvider)
                .initializeAndSync(platform: 'app'),
          );
        }
        // Check if onboarding is completed
        final isOnboarded = await authService.isOnboardingCompleted();
        if (mounted) {
          if (isOnboarded) {
            context.go('/home');
          } else {
            context.go('/setup');
          }
        }
      }
    } catch (e) {
      String errorMessage = 'エラーが発生しました';
      if (e.toString().contains('Invalid login credentials')) {
        errorMessage = 'メールアドレスまたはパスワードが正しくありません';
      } else if (e.toString().contains('User already registered')) {
        errorMessage = 'このメールアドレスは既に登録されています';
      } else if (e.toString().contains('Email not confirmed')) {
        errorMessage = 'メールアドレスの確認が完了していません';
      }
      setState(() => _errorMessage = errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // Logo / Title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.greenPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        size: 40,
                        color: AppColors.greenPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ガチトレ',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.greenPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AIパーソナルトレーナー',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Section title
              Center(
                child: Text(
                  _isSignUp ? '新規登録' : 'ログイン',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              AppTextField(
                controller: _emailController,
                label: 'メールアドレス',
                hint: 'example@email.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
              ),

              const SizedBox(height: 16),

              // Password field
              AppTextField(
                controller: _passwordController,
                label: 'パスワード',
                hint: '8文字以上',
                obscureText: _obscurePassword,
                prefixIcon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: _isSignUp ? '新規登録' : 'ログイン',
                  onPressed: _handleSubmit,
                  isLoading: _isLoading,
                ),
              ),

              const SizedBox(height: 16),

              // Forgot password
              if (!_isSignUp) ...[
                Center(
                  child: TextButton(
                    onPressed: () {
                      _showForgotPasswordDialog();
                    },
                    child: const Text(
                      'パスワードをお忘れですか？',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Switch between login and signup
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'すでにアカウントをお持ちの方は' : 'アカウントをお持ちでない方は',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isSignUp ? 'ログイン' : '新規登録',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.greenPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'パスワードリセット',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '登録済みのメールアドレスを入力してください。パスワードリセット用のリンクを送信します。',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'メールアドレス',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'キャンセル',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  await ref.read(authServiceProvider).resetPassword(email);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('パスワードリセットメールを送信しました'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('メールの送信に失敗しました'),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text(
              '送信',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.greenPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
