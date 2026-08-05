import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/list.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_settings_row.dart';
import '../../shared/presentation/pull_to_create_sensitivity_options.dart';
import '../../shared/view_model/app_settings_view_model.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settings =
        ref.watch(appSettingsViewModelProvider).value ?? const AppSettings();
    final notifier = ref.read(appSettingsViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(RemixIcons.arrow_left_s_line),
          tooltip: '返回',
        ),
        title: const Text('界面设置'),
      ),
      backgroundColor: colors.surface,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            AppSpacing.space24,
            AppSpacing.space20,
            AppSpacing.space24,
          ),
          children: [
            _SettingsSection(
              title: '界面显示',
              rows: [
                AppSettingsSwitchRow(
                  label: '记账悬浮按钮',
                  description: '在右下角显示快速记账按钮',
                  value: settings.showAddTransactionFab,
                  onChanged: notifier.setShowAddTransactionFab,
                ),
                AppSettingsSelectRow<PullToCreateSensitivity>(
                  label: '下拉灵敏度',
                  description: '调整首页下拉新增交易的距离灵敏度',
                  value: settings.pullToCreateSensitivity,
                  options: pullToCreateSensitivityOptions,
                  onChanged: notifier.setPullToCreateSensitivity,
                ),
                AppSettingsSwitchRow(
                  label: '导航栏文字',
                  description: '在底部导航图标下方显示文字标签',
                  value: settings.showBottomNavLabels,
                  onChanged: notifier.setShowBottomNavLabels,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: Text(title, style: context.appTextStyles.groupTitle),
        ),
        const SizedBox(height: AppSpacing.space8),
        AppSurface(
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                rows[index],
                if (index < rows.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                    ),
                    child: Divider(height: AppListTokens.dividerThickness),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
