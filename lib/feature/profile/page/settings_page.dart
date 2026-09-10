import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/list.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_settings_row.dart';
import '../../../design_system/widget/app_surface.dart';
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
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '设置'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space8,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children: [
                  _SettingsSection(
                    title: '界面设置',
                    rows: [
                      AppSettingsSwitchRow(
                        label: '记账悬浮按钮',
                        value: settings.showAddTransactionFab,
                        onChanged: notifier.setShowAddTransactionFab,
                      ),
                      AppSettingsSelectRow<PullToCreateSensitivity>(
                        label: '下拉灵敏度',
                        value: settings.pullToCreateSensitivity,
                        options: pullToCreateSensitivityOptions,
                        onChanged: notifier.setPullToCreateSensitivity,
                      ),
                      AppSettingsSwitchRow(
                        label: '导航栏文字',
                        value: settings.showBottomNavLabels,
                        onChanged: notifier.setShowBottomNavLabels,
                      ),
                    ],
                  ),
                ],
              ),
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
