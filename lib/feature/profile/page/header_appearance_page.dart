import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/shared/app_appearance_settings.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../view_model/header_appearance_view_model.dart';
import '../widget/appearance_editor_scaffold.dart';
import '../widget/chrome_appearance_preview.dart';
import '../widget/glass_settings_editor.dart';

class HeaderAppearancePage extends ConsumerWidget {
  const HeaderAppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(headerAppearanceViewModelProvider);
    final state = asyncState.value;
    final notifier = ref.read(headerAppearanceViewModelProvider.notifier);
    final ready = state != null && !asyncState.isLoading;
    return AppearanceEditorScaffold(
      title: '顶部外观',
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
            title: '无法加载顶部外观',
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
    HeaderAppearanceState state,
    HeaderAppearanceViewModel notifier,
  ) => ListView(
    key: const ValueKey('header-appearance-settings'),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.space16,
      AppSpacing.space8,
      AppSpacing.space16,
      AppSpacing.space24,
    ),
    children: [
      Text('样式预览', style: context.appTextStyles.subsectionTitle),
      const SizedBox(height: AppSpacing.space8),
      HeaderAppearancePreview(appearance: state.appearance),
      const SizedBox(height: AppSpacing.space16),
      Text(
        state.hasChanges ? '未保存' : '调整后点击右上角保存',
        style: context.appTextStyles.listSupporting,
      ),
      const SizedBox(height: AppSpacing.space16),
      AppListSection(
        header: const AppSectionHeader(title: '顶部样式'),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppChoiceChipGroup<AppHeaderStyle>(
                  options: const [
                    AppChoiceChipOption(
                      value: AppHeaderStyle.classic,
                      label: '经典',
                    ),
                    AppChoiceChipOption(
                      value: AppHeaderStyle.frostedGlass,
                      label: '玻璃',
                    ),
                  ],
                  selected: state.appearance.headerStyle,
                  onChanged: notifier.setStyle,
                  enabled: !state.submitting,
                ),
                const SizedBox(height: AppSpacing.space12),
                Text(
                  state.appearance.headerStyle == AppHeaderStyle.classic
                      ? '纯色背景，控件使用平面样式。'
                      : '磨砂背景，控件使用悬浮玻璃样式。',
                  style: context.appTextStyles.listSupporting,
                ),
              ],
            ),
          ),
        ],
      ),
      if (state.appearance.headerStyle == AppHeaderStyle.frostedGlass) ...[
        const SizedBox(height: AppSpacing.space16),
        AppListSection(
          header: const AppSectionHeader(title: '背景玻璃'),
          children: [
            GlassSettingsEditor(
              value: state.appearance.headerBackgroundGlass,
              showShadowControl: false,
              onChanged: state.submitting ? null : notifier.setBackgroundGlass,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space16),
        AppListSection(
          header: const AppSectionHeader(title: '控件玻璃'),
          children: [
            GlassSettingsEditor(
              value: state.appearance.headerControlGlass,
              onChanged: state.submitting ? null : notifier.setControlGlass,
            ),
          ],
        ),
      ],
    ],
  );
}
