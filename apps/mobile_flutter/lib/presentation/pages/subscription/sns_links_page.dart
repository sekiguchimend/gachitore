import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/subscription_models.dart';

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
    // TODO: Load existing links from backend
    setState(() {
      if (_links.isEmpty) {
        _links.add(SnsLinkInput());
      }
    });
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
      backgroundColor: const Color(0xFF323232),
      appBar: AppBar(
        title: const Text('SNSリンク設定', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveLinks,
              child: const Text(
                '保存',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'プロフィールに表示するSNSリンクを追加',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          ..._links.asMap().entries.map((entry) {
            final index = entry.key;
            final link = entry.value;
            return _buildLinkInput(index, link);
          }),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addLink,
            icon: const Icon(Icons.add),
            label: const Text('リンクを追加'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkInput(int index, SnsLinkInput link) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
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
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_links.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeLink(index),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: link.typeController.text.isEmpty ? null : link.typeController.text,
            decoration: const InputDecoration(
              labelText: 'SNSの種類',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white),
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
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'URL',
              labelStyle: TextStyle(color: Colors.white70),
              hintText: 'https://...',
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
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
