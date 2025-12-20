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
            '本アプリは、サービス提供のために以下の情報を取得・保存する場合があります。\n'
            '\n'
            '【アカウント情報】\n'
            '- メールアドレス\n'
            '\n'
            '【プロフィール/目標情報】\n'
            '- 表示名、性別、出生年、身長、トレーニングレベル、目標\n'
            '- 利用環境（ジム/自宅、器具など）、制約情報（ケガ・痛み等の自己申告）\n'
            '\n'
            '【身体・健康に関する記録（ユーザー入力）】\n'
            '- 体重、体脂肪率、睡眠時間、歩数、メモ\n'
            '\n'
            '【トレーニング/食事の記録（ユーザー入力）】\n'
            '- トレーニング内容（種目、セット、重量、回数、休憩等）\n'
            '- 食事内容（食事、品目、栄養素、メモ等）\n'
            '\n'
            '【写真（ユーザーが撮影/選択してアップロードしたもの）】\n'
            '- 進捗管理等のため、写真とそのメタデータ（作成日時等）\n'
            '\n'
            '【AI機能の入力/履歴】\n'
            '- AIへの質問文、AI回答、推奨内容、会話セッション情報\n'
            '\n'
            '【通知】\n'
            '- プッシュ通知の配信に必要な端末トークン（FCMトークン）等\n'
            '\n'
            '【お問い合わせ】\n'
            '- 件名、内容、（ログイン中の）メールアドレス\n'
            '- 端末情報（任意で送信される場合）\n'
            '\n'
            '【ログ情報】\n'
            '- サーバーへのアクセスログ（IPアドレス、日時、リクエスト情報等）',
          ),
          SizedBox(height: 16),
          _SectionTitle('2. 利用目的'),
          _BodyText(
            '取得した情報は、以下の目的で利用します。\n'
            '- サービス提供・本人確認\n'
            '- トレーニング/食事/身体データの記録・可視化\n'
            '- AI機能による提案・アドバイスの生成\n'
            '- プッシュ通知（リマインダー/AI返信通知等）の配信\n'
            '- 機能改善・品質向上\n'
            '- 不具合調査・サポート対応\n'
            '- 不正利用防止・セキュリティ確保',
          ),
          SizedBox(height: 16),
          _SectionTitle('3. 外部送信/第三者提供'),
          _BodyText(
            '本アプリは、以下の外部サービスを利用する場合があります。\n'
            '- Supabase（データベース/ストレージ/サーバー機能等）\n'
            '- Firebase Cloud Messaging（プッシュ通知）\n'
            '- Google Gemini API（AI回答の生成）\n'
            '\n'
            'これらのサービス提供のために必要な範囲で、ユーザーが入力した情報（トレーニング・食事・身体データ、AIへの入力など）を外部に送信する場合があります。\n'
            '\n'
            'なお、法令に基づく場合等を除き、本人の同意なく第三者に提供（販売/貸与）しません。',
          ),
          SizedBox(height: 16),
          _SectionTitle('4. 保管期間'),
          _BodyText(
            '利用目的の達成に必要な期間、合理的な範囲で保管します。\n'
            'ユーザーがアプリ上で削除した写真等は、原則としてサーバー上のデータも削除されます。',
          ),
          SizedBox(height: 16),
          _SectionTitle('5. ユーザーによる設定/削除'),
          _BodyText(
            'ユーザーは、以下の操作が可能です。\n'
            '- 写真の削除（写真画面から削除）\n'
            '- プッシュ通知のON/OFF（設定画面から変更）\n'
            '\n'
            'アカウントや保存データの削除等をご希望の場合は、設定画面の「お問い合わせ」からご連絡ください。',
          ),
          SizedBox(height: 16),
          _SectionTitle('6. 安全管理措置'),
          _BodyText(
            '取得した情報の漏えい・滅失・毀損等を防止するため、通信の暗号化、アクセス制御等の必要かつ適切な措置を講じます。',
          ),
          SizedBox(height: 16),
          _SectionTitle('7. 改定'),
          _BodyText(
            '本ポリシーは、必要に応じて内容を改定することがあります。重要な変更がある場合は、アプリ内等で告知します。',
          ),
          SizedBox(height: 16),
          _SectionTitle('8. お問い合わせ'),
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


