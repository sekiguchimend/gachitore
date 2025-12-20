import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/page_header.dart';

class SupportContactPage extends ConsumerStatefulWidget {
  const SupportContactPage({super.key});

  @override
  ConsumerState<SupportContactPage> createState() => _SupportContactPageState();
}

class _SupportContactPageState extends ConsumerState<SupportContactPage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('コピーしました'),
        backgroundColor: AppColors.greenPrimary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _send() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('件名と内容を入力してください'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final support = ref.read(supportServiceProvider);
      await support.sendContact(
        subject: subject,
        message: message,
        platform: 'app',
      );
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('送信しました'),
          backgroundColor: AppColors.greenPrimary,
          duration: Duration(seconds: 2),
        ),
      );
      _subjectController.clear();
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('送信に失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );

      // 失敗時は保険としてクリップボードへコピーできるようにする
      await _copyToClipboard('【件名】$subject\n\n【内容】\n$message');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(title: 'お問い合わせ'),
              AppCard(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'フィードバック / 不具合報告',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _subjectController,
                      label: '件名',
                      hint: '例：ログインできない',
                      maxLength: 60,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _messageController,
                      label: '内容',
                      hint: '状況や手順、エラー表示などをできるだけ詳しく',
                      maxLines: 6,
                      maxLength: 1000,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text: '送信',
                      isExpanded: true,
                      isLoading: _isSending,
                      onPressed: _isSending ? null : _send,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _copyToClipboard(
                        '端末情報（任意）：\n'
                        '- OS：\n'
                        '- アプリバージョン：\n'
                        '- 発生日時：\n'
                        '- 再現手順：\n',
                      ),
                      child: const Text(
                        'テンプレートをコピー',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}


