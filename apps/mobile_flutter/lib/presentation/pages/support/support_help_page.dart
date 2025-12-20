import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/app_card.dart';

class SupportHelpPage extends StatelessWidget {
  const SupportHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(title: 'ヘルプ'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'よくある質問',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._faqItems.map((item) => _FaqCard(item: item)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });
}

const List<_FaqItem> _faqItems = [
  _FaqItem(
    question: 'アカウントにログインできません',
    answer:
        'メールアドレス/パスワードが正しいか確認してください。\n'
        'パスワードを忘れた場合は、ログイン画面の「パスワードを忘れた方」から再設定できます。',
  ),
  _FaqItem(
    question: '体重や身長などのデータを変更したい',
    answer:
        '設定画面の「身体データ」から体重/身長/年齢を変更できます。\n'
        '入力後に保存されない場合は通信状況をご確認ください。',
  ),
  _FaqItem(
    question: '通知を止めたい',
    answer:
        '設定画面の「アプリ設定」→「通知」をオフにしてください。\n'
        '端末側の通知設定でブロックされている場合もあります。',
  ),
  _FaqItem(
    question: 'データが更新されません',
    answer:
        '一時的な通信不良の可能性があります。アプリを再起動して再度お試しください。\n'
        '改善しない場合はお問い合わせから状況をお知らせください。',
  ),
];

class _FaqCard extends StatelessWidget {
  final _FaqItem item;

  const _FaqCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.answer,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}


