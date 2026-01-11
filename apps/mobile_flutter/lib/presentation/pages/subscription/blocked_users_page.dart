import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';

/// ブロックしたユーザー一覧ページ（Premium限定）
class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  @override
  Widget build(BuildContext context) {
    final blockedUsersAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF323232),
      appBar: AppBar(
        title: const Text('ブロック中のユーザー', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: blockedUsersAsync.when(
        data: (blockedUserIds) {
          if (blockedUserIds.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'ブロック中のユーザーはいません',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: blockedUserIds.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final userId = blockedUserIds[index];
              return _buildBlockedUserCard(userId);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'エラー: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedUserCard(String userId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF1E1E1E),
            child: Icon(Icons.person, color: Colors.white54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ユーザー ID: ${userId.substring(0, 8)}...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ブロック中',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _unblockUser(userId),
            child: const Text(
              'ブロック解除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('ブロック解除', style: TextStyle(color: Colors.white)),
        content: const Text(
          'このユーザーのブロックを解除しますか？\n解除すると、このユーザーの投稿が再び表示されるようになります。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ブロック解除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      await subscriptionService.unblockUser(userId);

      // Refresh blocked users list
      ref.invalidate(blockedUsersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ブロックを解除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ブロック解除に失敗しました: $e')),
        );
      }
    }
  }
}

/// ユーザーをブロックするダイアログ
Future<void> showBlockUserDialog(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String userName,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('ユーザーをブロック', style: TextStyle(color: Colors.white)),
      content: Text(
        '$userName をブロックしますか？\n\nブロックすると：\n• このユーザーの投稿が表示されなくなります\n• このユーザーはあなたのプロフィールや投稿を見ることができなくなります',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('ブロック'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    final subscriptionService = ref.read(subscriptionServiceProvider);
    await subscriptionService.blockUser(userId);

    // Refresh blocked users list
    ref.invalidate(blockedUsersProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ユーザーをブロックしました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ブロックに失敗しました: $e')),
      );
    }
  }
}
