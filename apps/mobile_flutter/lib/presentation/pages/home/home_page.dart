import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/ai_models.dart';
import '../../../data/models/dashboard_models.dart';
import '../../widgets/home/chat_input_field.dart';
import '../../widgets/home/chat_message_bubble.dart';
import '../../widgets/home/typing_indicator.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
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

      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response.answerText,
          isUser: false,
          timestamp: DateTime.now(),
          recommendations: response.recommendations,
        ));
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: 'エラーが発生しました。もう一度お試しください。',
          isUser: false,
          timestamp: DateTime.now(),
        ));
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
            _buildHeader(),

            // Daily Summary (collapsible)
            _buildDailySummary(),

            // Quick Actions
            _buildQuickActions(),

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
              onCameraTap: () {
                // TODO: Open camera/gallery
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: Text(
                'ガチトレ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Positioned(
              left: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.greenPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: AppColors.greenPrimary,
                  size: 20,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                onPressed: () => context.go('/settings'),
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummary() {
    if (_isLoadingDashboard) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.greenPrimary,
          ),
        ),
      );
    }

    final weight = _dashboard?.bodyMetrics?.weightKg?.toStringAsFixed(1) ?? '--';
    final calories = _dashboard?.nutrition?.calories.toString() ?? '0';
    final protein = _dashboard?.nutrition?.proteinG.round().toString() ?? '0';
    final workoutStatus = _dashboard?.tasks.workoutLogged == true ? '完了' : '未完了';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMiniStatCard(
              icon: Icons.monitor_weight_outlined,
              label: '体重',
              value: weight,
              unit: 'kg',
            ),
            const SizedBox(width: 8),
            _buildMiniStatCard(
              icon: Icons.local_fire_department_outlined,
              label: 'カロリー',
              value: calories,
              unit: 'kcal',
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            _buildMiniStatCard(
              icon: Icons.egg_outlined,
              label: 'タンパク質',
              value: protein,
              unit: 'g',
              color: AppColors.info,
            ),
            const SizedBox(width: 8),
            _buildMiniStatCard(
              icon: Icons.fitness_center,
              label: 'トレーニング',
              value: workoutStatus,
              color: _dashboard?.tasks.workoutLogged == true
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required String label,
    required String value,
    String? unit,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color ?? AppColors.textPrimary,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickActionButton(
              '今日のメニュー',
              Icons.list_alt,
              () => _sendMessage('今日のトレーニングメニューを教えて'),
            ),
            const SizedBox(width: 8),
            _buildQuickActionButton(
              '食事提案',
              Icons.restaurant,
              () => _sendMessage('今日の残りのPFCバランスを考えた食事を提案して'),
            ),
            const SizedBox(width: 8),
            _buildQuickActionButton(
              '停滞診断',
              Icons.trending_up,
              () => _sendMessage('最近の進捗を分析して、停滞していないか診断して'),
            ),
            const SizedBox(width: 8),
            _buildQuickActionButton(
              'フォーム確認',
              Icons.videocam,
              () {
                // TODO: Open camera for form check
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.greenPrimary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.greenPrimary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: AppColors.greenPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.greenPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
