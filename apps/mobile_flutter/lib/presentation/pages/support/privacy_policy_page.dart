import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/app_card.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              PageHeader(title: 'プライバシーポリシー'),
              _PolicyBody(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyBody extends StatelessWidget {
  const _PolicyBody();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('1. 取得する情報'),
          _BodyText(
            '本アプリは、サービス提供のために以下の情報を取得する場合があります。\n'
            '- アカウント情報（メールアドレス等）\n'
            '- 身体データ（体重/身長/年齢など、ユーザーが入力したもの）\n'
            '- 利用状況（機能利用・エラー情報など）',
          ),
          SizedBox(height: 16),
          _SectionTitle('2. 利用目的'),
          _BodyText(
            '取得した情報は、以下の目的で利用します。\n'
            '- サービス提供・本人確認\n'
            '- 機能改善・品質向上\n'
            '- 不具合調査・サポート対応',
          ),
          SizedBox(height: 16),
          _SectionTitle('3. 第三者提供'),
          _BodyText(
            '法令に基づく場合等を除き、本人の同意なく第三者に提供しません。',
          ),
          SizedBox(height: 16),
          _SectionTitle('4. 保管期間'),
          _BodyText(
            '利用目的の達成に必要な期間、合理的な範囲で保管します。',
          ),
          SizedBox(height: 16),
          _SectionTitle('5. お問い合わせ'),
          _BodyText('設定画面の「お問い合わせ」からご連絡ください。'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.55,
        color: AppColors.textSecondary,
      ),
    );
  }
}


