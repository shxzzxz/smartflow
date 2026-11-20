import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../../design_system/widget/app_settings_row.dart';
import '../../shared/presentation/bottom_navigation_style_options.dart';
import '../view_model/navigation_appearance_view_model.dart';
import '../widget/appearance_editor_scaffold.dart';
import '../widget/chrome_appearance_preview.dart';
import '../widget/glass_settings_editor.dart';

class NavigationAppearancePage extends ConsumerWidget {
  const NavigationAppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(navigationAppearanceViewModelProvider);
    final state = asyncState.value;
    final notifier = ref.read(navigationAppearanceViewModelProvider.notifier);
    final ready = state != null && !asyncState.isLoading;
    return AppearanceEditorScaffold(
      title: '导航栏外观',
      hasChanges: state?.hasChanges ?? false,
      submitting: state?.submitting ?? false,
      onRestoreDefaults: ready ? notifier.restoreDefaults : null,
      onSave: ready ? notifier.save : null,
      onDiscardChanges: notifier.discardChanges,
      child: asyncState.when(
        skipLoadingOnRefresh: false,
        data: (state) => _buildEditor(context, state, notifier),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppEmptyState(
            title: '无法加载导航栏外观',
            message: '请稍后重试',
            action: TextButton(
              onPressed: notifier.retry,
              child: const Text('重试'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    NavigationAppearanceState state,
    NavigationAppearanceViewModel notifier,
  ) => ListView(
    key: const ValueKey('navigation-appearance-settings'),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.space16,
      AppSpacing.space8,
      AppSpacing.space16,
      AppSpacing.space24,
    ),
    children: [
      Text('样式预览', style: context.appTextStyles.subsectionTitle),
      const SizedBox(height: AppSpacing.space8),
      NavigationAppearancePreview(
        style: state.style,
        showLabels: state.showLabels,
        glass: state.glass,
      ),
      const SizedBox(height: AppSpacing.space16),
      Text(
        state.hasChanges ? '未保存' : '调整后点击右上角保存',
        style: context.appTextStyles.listSupporting,
      ),
      const SizedBox(height: AppSpacing.space16),
      AppListSection(
        header: const AppSectionHeader(title: '导航栏设置'),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('导航栏样式', style: context.appTextStyles.settingsTitle),
                const SizedBox(height: AppSpacing.space12),
                AppChoiceChipGroup<BottomNavigationStyle>(
                  options: bottomNavigationStyleOptions,
                  selected: state.style,
                  onChanged: notifier.setStyle,
                  enabled: !state.submitting,
                ),
              ],
            ),
          ),
          AppSettingsSwitchRow(
            label: '导航栏文字',
            value: state.showLabels,
            onChanged: notifier.setShowLabels,
            enabled: !state.submitting,
          ),
        ],
      ),
      if (state.style == BottomNavigationStyle.frostedGlass) ...[
        const SizedBox(height: AppSpacing.space16),
        AppListSection(
          header: const AppSectionHeader(title: '玻璃效果'),
          children: [
            GlassSettingsEditor(
              value: state.glass,
              onChanged: state.submitting ? null : notifier.setGlass,
            ),
          ],
        ),
      ],
    ],
  );
}
