part of 'settings_page.dart';

extension _SettingsPageUi on _SettingsPageState {
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          '設定',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.greenPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.greenPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Edit Button
          IconButton(
            onPressed: () => _showProfileEditor(),
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    // ボリュームの表示を整形（小数点1桁）
    final volumeStr = _totalVolume >= 1
        ? _totalVolume.toStringAsFixed(1)
        : (_totalVolume * 1000).toStringAsFixed(0);
    final volumeUnit = _totalVolume >= 1 ? 't' : 'kg';

    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('ワークアウト', '$_totalWorkouts', '回')),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('連続日数', '$_streakDays', '日')),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('総ボリューム', volumeStr, volumeUnit)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greenPrimary,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


