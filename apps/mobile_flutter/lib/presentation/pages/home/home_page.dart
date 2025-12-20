import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/auth/secure_token_storage.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/ai_models.dart';
import '../../../data/models/dashboard_models.dart';
import '../../widgets/home/chat_input_field.dart';
import '../../widgets/home/chat_message_bubble.dart';
import '../../widgets/home/typing_indicator.dart';
import '../../widgets/home/home_top_header.dart';
import '../../widgets/home/daily_summary_strip.dart';
import '../../widgets/home/quick_actions_strip.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _legacyChatStorageKey = 'chat_history_v1';
  static const _chatStorageKeyPrefix = 'chat_history_v1_';
  static const _chatMaxCount = 4;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isLoadingDashboard = true;
  DashboardResponse? _dashboard;
  String? _currentSessionId;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _loadWelcomeMessage();
    _loadChatHistory();
    _loadInboxMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    try {
      final dashboardService = ref.read(dashboardServiceProvider);
      final dashboard = await dashboardService.getDashboard();
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDashboard = false);
      }
    }
  }

  void _loadWelcomeMessage() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'おはようございます';
    } else if (hour < 18) {
      greeting = 'こんにちは';
    } else {
      greeting = 'こんばんは';
    }

    _messages.add(ChatMessage(
      id: '0',
      content: '$greeting！今日も頑張りましょう。\n\n何かお手伝いできることはありますか？',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  bool _isPersistableChatMessage(ChatMessage m) {
    if (m.id == '0') return false; // welcome message
    if (m.id.startsWith('inbox-')) return false; // inbox notifications
    return true;
  }

  void _applyChatHistoryLimitInState() {
    final persistableIndices = <int>[];
    for (var i = 0; i < _messages.length; i++) {
      if (_isPersistableChatMessage(_messages[i])) {
        persistableIndices.add(i);
      }
    }

    final overflow = persistableIndices.length - _chatMaxCount;
    if (overflow <= 0) return;

    final indicesToRemove = persistableIndices.take(overflow).toList();
    for (final idx in indicesToRemove.reversed) {
      _messages.removeAt(idx);
    }
  }

  void _setStateAndPersist(VoidCallback fn) {
    setState(fn);
    _saveChatHistory();
  }

  Future<String> _currentChatStorageKey() async {
    final userId = await SecureTokenStorage.getUserId();
    if (userId == null || userId.isEmpty) return _legacyChatStorageKey;
    return '$_chatStorageKeyPrefix$userId';
  }

  Future<void> _migrateLegacyChatHistoryIfNeeded() async {
    try {
      final userId = await SecureTokenStorage.getUserId();
      if (userId == null || userId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final userKey = '$_chatStorageKeyPrefix$userId';
      final hasUserKey = prefs.containsKey(userKey);
      final legacy = prefs.getString(_legacyChatStorageKey);

      // 旧キーがあり、ユーザー別キーが無い場合のみ移行する
      if (!hasUserKey && legacy != null && legacy.isNotEmpty) {
        await prefs.setString(userKey, legacy);
      }

      // 旧キーはアカウント切り替え時に漏れて見えるので削除する
      if (prefs.containsKey(_legacyChatStorageKey)) {
        await prefs.remove(_legacyChatStorageKey);
      }
    } catch (_) {
      // ignore (migration is best-effort)
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _currentChatStorageKey();
      final persistable = _messages.where(_isPersistableChatMessage).toList();
      final trimmed = persistable.length <= _chatMaxCount
          ? persistable
          : persistable.sublist(persistable.length - _chatMaxCount);
      final encoded =
          jsonEncode(trimmed.map((m) => m.toJson()).toList(growable: false));
      await prefs.setString(key, encoded);
    } catch (_) {
      // ignore (persistence is best-effort)
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacyChatHistoryIfNeeded();
      final key = await _currentChatStorageKey();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final restored = decoded
          .whereType<Map>()
          .map((m) => ChatMessage.fromJson(m.cast<String, dynamic>()))
          .toList();

      if (!mounted) return;
      setState(() {
        _messages.addAll(restored);
        _applyChatHistoryLimitInState();
      });
      _scrollToBottom();
    } catch (e) {
      // If corrupted, clear it to avoid repeated exceptions.
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = await _currentChatStorageKey();
        await prefs.remove(key);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('チャット履歴を復元できなかったため初期化しました'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadInboxMessages() async {
    try {
      final aiService = ref.read(aiServiceProvider);
      final inbox = await aiService.getInboxMessages();
      if (inbox.isEmpty) return;

      if (!mounted) return;
      setState(() {
        for (final m in inbox) {
          _messages.add(ChatMessage(
            id: 'inbox-${m.id}',
            content: m.content,
            isUser: false,
            timestamp: m.createdAt,
          ));
        }
      });
      _scrollToBottom();
    } catch (_) {
      // ignore (inbox is optional)
    }
  }

  Future<void> _sendMessage([String? customMessage]) async {
    final text = customMessage ?? _messageController.text.trim();
    if (text.isEmpty) return;

    _setStateAndPersist(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _applyChatHistoryLimitInState();
      if (customMessage == null) _messageController.clear();
      _isSending = true;
    });

    _scrollToBottom();

    try {
      final aiService = ref.read(aiServiceProvider);
      final response = await aiService.askAi(AskRequest(
        message: text,
        sessionId: _currentSessionId,
      ));

      _currentSessionId = response.sessionId;

      _setStateAndPersist(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response.answerText,
          isUser: false,
          timestamp: DateTime.now(),
          recommendations: response.recommendations,
        ));
        _applyChatHistoryLimitInState();
        _isSending = false;
      });
    } catch (e) {
      _setStateAndPersist(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: 'エラーが発生しました。もう一度お試しください。',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _applyChatHistoryLimitInState();
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            HomeTopHeader(onSettingsTap: () => context.go('/settings')),

            // Daily Summary (collapsible)
            DailySummaryStrip(isLoading: _isLoadingDashboard, dashboard: _dashboard),

            // Quick Actions
            QuickActionsStrip(onSendMessage: (m) => _sendMessage(m)),

            // Chat Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isSending) {
                    return const TypingIndicator();
                  }
                  return ChatMessageBubble(message: _messages[index]);
                },
              ),
            ),

            // Input Field
            ChatInputField(
              controller: _messageController,
              onSend: () => _sendMessage(),
            ),
          ],
        ),
      ),
    );
  }
}
