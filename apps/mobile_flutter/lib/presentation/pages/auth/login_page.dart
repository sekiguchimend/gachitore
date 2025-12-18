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

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'メールアドレスとパスワードを入力してください');
      return;
    }

    if (_isSignUp && password.length < 8) {
      setState(() => _errorMessage = 'パスワードは8文字以上で入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      if (_isSignUp) {
        await authService.signUp(email: email, password: password);
        // GoRouterのredirectが未ログイン扱いのままだと/loginに戻されるので、
        // ログイン状態を明示的に更新する
        AppRouter.authNotifier.setLoggedIn(true);
        unawaited(ref.read(pushNotificationServiceProvider).initializeAndSync(platform: 'app'));
        // After sign up, navigate to setup for onboarding
        if (mounted) {
          context.go('/setup');
        }
      } else {
        await authService.signIn(email: email, password: password);
        // GoRouterのredirectが未ログイン扱いのままだと遷移できないため更新
        AppRouter.authNotifier.setLoggedIn(true);
        unawaited(ref.read(pushNotificationServiceProvider).initializeAndSync(platform: 'app'));
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
    } catch (e) {
      setState(() => _errorMessage = 'Googleログインに失敗しました');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithApple();
    } catch (e) {
      setState(() => _errorMessage = 'Appleログインに失敗しました');
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

              const SizedBox(height: 60),

              // Toggle Login/SignUp
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton('ログイン', !_isSignUp, () {
                        setState(() => _isSignUp = false);
                      }),
                      _buildToggleButton('新規登録', _isSignUp, () {
                        setState(() => _isSignUp = true);
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

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
              AppButton(
                text: _isSignUp ? '新規登録' : 'ログイン',
                onPressed: _handleSubmit,
                isLoading: _isLoading,
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

              // Divider with text
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'または',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ],
              ),

              const SizedBox(height: 24),

              // Social login buttons
              AppOutlinedButton(
                text: 'Googleでログイン',
                icon: Icons.g_mobiledata,
                onPressed: _handleGoogleSignIn,
              ),

              const SizedBox(height: 12),

              AppOutlinedButton(
                text: 'Appleでログイン',
                icon: Icons.apple,
                onPressed: _handleAppleSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
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
