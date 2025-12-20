import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/app_card.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              PageHeader(title: '利用規約'),
              _TermsBody(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('1. 適用'),
          _BodyText('本規約は、本アプリの利用に関する条件を定めるものです。'),
          SizedBox(height: 16),
          _SectionTitle('2. 禁止事項'),
          _BodyText(
            'ユーザーは、以下の行為を行ってはなりません。\n'
            '- 法令または公序良俗に違反する行為\n'
            '- 本アプリの運営を妨害する行為\n'
            '- 不正アクセス等の行為',
          ),
          SizedBox(height: 16),
          _SectionTitle('3. 免責'),
          _BodyText(
            '本アプリは、提供情報の正確性・完全性を保証しません。'
            'ユーザーは自己の責任において本アプリを利用するものとします。',
          ),
          SizedBox(height: 16),
          _SectionTitle('4. 規約変更'),
          _BodyText('本規約は必要に応じて変更される場合があります。'),
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


