part of 'settings_page.dart';

extension _SettingsPageDialogs on _SettingsPageState {
  Future<void> _logout() async {
    // ログアウト時に「前ユーザーのキャッシュ」が残るのを防ぐ
    final push = ref.read(pushNotificationServiceProvider);
    final authService = ref.read(authServiceProvider);

    try {
      // 可能ならサーバー側の送信対象から外す（ベストエフォート）
      await push.disablePush().timeout(const Duration(seconds: 2));
    } catch (_) {
      // ignore
    }

    try {
      await authService.signOut();
    } catch (_) {
      // サーバー側signout失敗でもローカルの状態は落とす
      await authService.signOut();
    }

    try {
      // チャットの端末キャッシュをクリア（ユーザー別キー）
      await ChatHistoryStorage.clearForCurrentUser();
    } catch (_) {
      // ignore
    }

    // ルータの認証状態も明示的に落とす（redirectの揺れ防止）
    AppRouter.authNotifier.setLoggedIn(false);

    if (!mounted) return;
    context.go('/login');
  }

  void _showGoalPicker() {
    _showPickerSheet(
      '目標を選択',
      ['筋肥大', '減量', 'パワー向上', '健康維持'],
      _user?.goal ?? '',
      (value) async {
        // 日本語→英語変換してAPIに送信
        final goalEnValue = UserProfile.goalJaToEn[value] ?? 'hypertrophy';
        await _updateProfile(goal: goalEnValue);
        if (mounted && _user != null) {
          setState(() {
            _user = _user!.copyWith(goal: value);
          });
        }
      },
    );
  }

  void _showLevelPicker() {
    _showPickerSheet(
      'トレーニングレベル',
      ['初心者', '中級者', '上級者'],
      _user?.level ?? '',
      (value) async {
        // 日本語→英語変換してAPIに送信
        final levelEnValue = UserProfile.levelJaToEn[value] ?? 'beginner';
        await _updateProfile(trainingLevel: levelEnValue);
        if (mounted && _user != null) {
          setState(() {
            _user = _user!.copyWith(level: value);
          });
        }
      },
    );
  }

  void _showPickerSheet(
    String title,
    List<String> options,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PickerBottomSheet(
        title: title,
        options: options,
        currentValue: currentValue,
        onSelected: (value) {
          onSelected(value);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showProfileEditor() {
    final controller = TextEditingController(text: _user?.name ?? '');
    _showInputDialog(
      title: '名前を編集',
      suffix: '',
      controller: controller,
      keyboardType: TextInputType.text,
      onSave: (value) async {
        final newName = value.trim();
        if (newName.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('名前を入力してください'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        if (_user != null) {
          await _updateProfile(displayName: newName);
          if (mounted) {
            setState(() {
              _user = _user!.copyWith(name: newName);
            });
          }
        }
      },
    );
  }

  void _showPfcEditor() {
    final user = _user ?? UserProfile.empty();
    final calController = TextEditingController(text: user.targetCalories.toString());
    final proteinController =
        TextEditingController(text: user.targetProteinG.toString());
    final fatController = TextEditingController(text: user.targetFatG.toString());
    final carbsController =
        TextEditingController(text: user.targetCarbsG.toString());

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    '1日のPFC目標を編集',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPfcField(
                label: 'カロリー（1日）',
                suffix: 'kcal',
                controller: calController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPfcField(
                      label: 'タンパク質（1日）',
                      suffix: 'g',
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPfcField(
                      label: '脂質（1日）',
                      suffix: 'g',
                      controller: fatController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPfcField(
                label: '炭水化物（1日）',
                suffix: 'g',
                controller: carbsController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              AppButton(
                text: '保存',
                isLoading: isSaving,
                onPressed: isSaving
                    ? null
                    : () async {
                        final calories = int.tryParse(calController.text.trim());
                        final protein = int.tryParse(proteinController.text.trim());
                        final fat = int.tryParse(fatController.text.trim());
                        final carbs = int.tryParse(carbsController.text.trim());

                        if (calories == null ||
                            protein == null ||
                            fat == null ||
                            carbs == null) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('数値を正しく入力してください'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        setSheetState(() => isSaving = true);
                        try {
                          await _updateProfile(
                            targetCalories: calories,
                            targetProteinG: protein,
                            targetFatG: fat,
                            targetCarbsG: carbs,
                          );

                          if (!mounted) return;
                          setState(() {
                            _user = user.copyWith(
                              targetCalories: calories,
                              targetProteinG: protein,
                              targetFatG: fat,
                              targetCarbsG: carbs,
                            );
                          });
                          Navigator.pop(sheetContext);
                        } catch (e) {
                          setSheetState(() => isSaving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text('保存に失敗しました: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPfcField({
    required String label,
    required String suffix,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: AppColors.bgSub,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  void _showWeightEditor() {
    final controller = TextEditingController(
      text: _user?.weight.toString() ?? '',
    );
    _showInputDialog(
      title: '体重を入力',
      suffix: 'kg',
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSave: (value) async {
        final weight = double.tryParse(value);
        if (weight != null && _user != null) {
          await _updateProfile(weightKg: weight);
          if (mounted) {
            setState(() {
              _user = _user!.copyWith(weight: weight);
            });
          }
        }
      },
    );
  }

  void _showHeightEditor() {
    final controller = TextEditingController(
      text: _user?.height.toInt().toString() ?? '',
    );
    _showInputDialog(
      title: '身長を入力',
      suffix: 'cm',
      controller: controller,
      keyboardType: TextInputType.number,
      onSave: (value) async {
        final height = double.tryParse(value);
        if (height != null && _user != null) {
          await _updateProfile(heightCm: height.toInt());
          if (mounted) {
            setState(() {
              _user = _user!.copyWith(height: height);
            });
          }
        }
      },
    );
  }

  void _showAgeEditor() {
    final controller = TextEditingController(
      text: _user?.age.toString() ?? '',
    );
    _showInputDialog(
      title: '年齢を入力',
      suffix: '歳',
      controller: controller,
      keyboardType: TextInputType.number,
      onSave: (value) async {
        final age = int.tryParse(value);
        if (age != null && _user != null) {
          // 年齢から生年を計算
          final birthYear = DateTime.now().year - age;
          await _updateProfile(birthYear: birthYear);
          if (mounted) {
            setState(() {
              _user = _user!.copyWith(age: age);
            });
          }
        }
      },
    );
  }

  void _showInputDialog({
    required String title,
    required String suffix,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required Future<void> Function(String) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                suffixText: suffix,
                suffixStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.bgSub,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onSave(controller.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'ログアウト',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'ログアウトしてもよろしいですか？',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'キャンセル',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _logout();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ログアウトに失敗しました'),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'ログアウト',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


