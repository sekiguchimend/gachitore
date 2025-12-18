part of 'muscle_page.dart';

extension _MusclePageHeader on _MusclePageState {
  Widget _buildHeader() {
    final tabs = ['種目', '履歴'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: PopupMenuButton<int>(
                offset: const Offset(0, 48),
                color: AppColors.bgCard,
                useRootNavigator: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (index) {
                  _tabController.animateTo(index);
                  setState(() {});
                },
                itemBuilder: (context) => [
                  PopupMenuItem<int>(
                    value: 0,
                    child: Row(
                      children: [
                        Icon(
                          _tabController.index == 0
                              ? Icons.check
                              : Icons.fitness_center,
                          size: 18,
                          color: _tabController.index == 0
                              ? AppColors.greenPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '種目',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _tabController.index == 0
                                ? AppColors.greenPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<int>(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(
                          _tabController.index == 1
                              ? Icons.check
                              : Icons.history,
                          size: 18,
                          color: _tabController.index == 1
                              ? AppColors.greenPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '履歴',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _tabController.index == 1
                                ? AppColors.greenPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[_tabController.index],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_less,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      // TODO: Open stats
                    },
                    icon: const Icon(
                      Icons.bar_chart,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Add new exercise
                    },
                    icon: const Icon(
                      Icons.add,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return const SizedBox.shrink();
  }
}


