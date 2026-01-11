import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/secure_token_storage.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/subscription_models.dart';
import '../../widgets/common/app_button.dart';

/// SNSリンク管理ページ（Basic/Premium限定）
class SnsLinksPage extends ConsumerStatefulWidget {
  const SnsLinksPage({super.key});

  @override
  ConsumerState<SnsLinksPage> createState() => _SnsLinksPageState();
}

class _SnsLinksPageState extends ConsumerState<SnsLinksPage> {
  final List<SnsLinkInput> _links = [];
  bool _isLoading = false;

  final List<String> _availableTypes = [
    'Twitter',
    'Instagram',
    'YouTube',
    'TikTok',
    'Facebook',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingLinks();
  }

  Future<void> _loadExistingLinks() async {
    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      final userId = await SecureTokenStorage.getUserId();

      if (userId == null) return;

      final existingLinks = await subscriptionService.getUserSnsLinks(userId);

      if (!mounted) return;

      setState(() {
        _links.clear();
        if (existingLinks.isEmpty) {
          _links.add(SnsLinkInput());
        } else {
          for (final link in existingLinks) {
            final input = SnsLinkInput();
            input.typeController.text = _capitalizeFirstLetter(link.type);
            input.urlController.text = link.url;
            _links.add(input);
          }
        }
      });
    } catch (e) {
      // エラーの場合は空のフォームを表示
      if (mounted) {
        setState(() {
          if (_links.isEmpty) {
            _links.add(SnsLinkInput());
          }
        });
      }
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _saveLinks() async {
    // Validate
    final validLinks = _links
        .where((link) =>
            link.typeController.text.isNotEmpty &&
            link.urlController.text.isNotEmpty)
        .toList();

    if (validLinks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('少なくとも1つのリンクを追加してください')),
      );
      return;
    }

    // Validate URLs
    for (final link in validLinks) {
      final url = link.urlController.text;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無効なURL: $url')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      final snsLinks = validLinks
          .map((link) => SnsLink(
                type: link.typeController.text.toLowerCase(),
                url: link.urlController.text,
              ))
          .toList();

      await subscriptionService.updateMySnsLinks(snsLinks);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SNSリンクを保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addLink() {
    setState(() {
      _links.add(SnsLinkInput());
    });
  }

  void _removeLink(int index) {
    setState(() {
      _links[index].dispose();
      _links.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (final link in _links) {
      link.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        title: const Text(
          'SNSリンク設定',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: AppColors.bgMain,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'プロフィールに表示するSNSリンクを追加',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ..._links.asMap().entries.map((entry) {
                  final index = entry.key;
                  final link = entry.value;
                  return _buildLinkInput(index, link);
                }),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addLink,
                  icon: const Icon(Icons.add, color: AppColors.greenPrimary),
                  label: const Text(
                    'リンクを追加',
                    style: TextStyle(
                      color: AppColors.greenPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.greenPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: SafeArea(
              top: false,
              child: AppButton(
                text: '保存',
                onPressed: _isLoading ? null : _saveLinks,
                isLoading: _isLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkInput(int index, SnsLinkInput link) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'リンク ${index + 1}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_links.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _removeLink(index),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: link.typeController.text.isEmpty ? null : link.typeController.text,
            decoration: InputDecoration(
              labelText: 'SNSの種類',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.bgSub,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: AppColors.bgCard,
            style: const TextStyle(color: AppColors.textPrimary),
            items: _availableTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                link.typeController.text = value;
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: link.urlController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'URL',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintText: 'https://...',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.bgSub,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }
}

class SnsLinkInput {
  final TextEditingController typeController = TextEditingController();
  final TextEditingController urlController = TextEditingController();

  void dispose() {
    typeController.dispose();
    urlController.dispose();
  }
}
