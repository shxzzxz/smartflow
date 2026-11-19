import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_appearance_settings.dart';
import '../../../design_system/theme/app_theme.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/appearance.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/theme_appearance_view_model.dart';
import '../widget/settings_color_row.dart';
import '../../../design_system/widget/app_scaffold.dart';

class ThemeAppearancePage extends ConsumerStatefulWidget {
  const ThemeAppearancePage({super.key});

  @override
  ConsumerState<ThemeAppearancePage> createState() =>
      _ThemeAppearancePageState();
}

class _ThemeAppearancePageState extends ConsumerState<ThemeAppearancePage> {
  bool _confirmingExit = false;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(themeAppearanceViewModelProvider);
    final state = asyncState.value;
    final notifier = ref.read(themeAppearanceViewModelProvider.notifier);
    final enabled = state != null && !asyncState.isLoading && !state.submitting;
    final inheritedTheme = Theme.of(context);
    final theme = state == null
        ? inheritedTheme
        : inheritedTheme.brightness == Brightness.dark
        ? AppTheme.dark(appearance: state.appearance)
        : AppTheme.light(appearance: state.appearance);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => PopScope<Object?>(
          canPop: state?.hasChanges != true && state?.submitting != true,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _requestExit(context);
          },
          child: AppScaffold(
            body: SafeArea(
              child: Column(
                children: [
                  AppPageHeader(
                    title: '主题外观',
                    onBack: () => _requestExit(context),
                    actions: [
                      AppHeaderIconButton(
                        icon: RemixIcons.refresh_line,
                        tooltip: '恢复默认',
                        onPressed: enabled ? notifier.restoreDefaults : null,
                      ),
                      AppHeaderTextButton(
                        label: state?.submitting == true ? '保存中' : '保存',
                        onPressed: enabled && state.hasChanges ? _save : null,
                      ),
                    ],
                  ),
                  Expanded(
                    child: asyncState.when(
                      skipLoadingOnRefresh: false,
                      data: (state) => _buildEditor(context, state, notifier),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => Center(
                        child: AppEmptyState(
                          title: '无法加载主题外观',
                          message: '请稍后重试',
                          action: TextButton(
                            onPressed: notifier.retry,
                            child: const Text('重试'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    ThemeAppearanceState state,
    ThemeAppearanceViewModel notifier,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    return ListView(
      key: const ValueKey('theme-appearance-settings'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space8,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        Text(
          state.hasChanges ? '未保存' : '调整后点击右上角保存',
          style: textStyles.listSupporting.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space16),
        AppListSection(
          header: const AppSectionHeader(title: '颜色'),
          children: [
            SettingsColorRow(
              label: '主题色',
              value: state.appearance.primaryColor,
              onChanged: state.submitting ? null : notifier.setPrimaryColor,
            ),
            SettingsColorRow(
              label: '背景基色',
              value: state.appearance.backgroundSeedColor,
              onChanged: state.submitting
                  ? null
                  : notifier.setBackgroundSeedColor,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space16),
        AppListSection(
          header: const AppSectionHeader(title: '背景'),
          children: [_BackgroundSettings(state: state, notifier: notifier)],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final outcome = await ref
        .read(themeAppearanceViewModelProvider.notifier)
        .save();
    if (!mounted) return;
    final message = switch (outcome) {
      UiActionSuccess() => '主题外观已保存',
      UiActionFailure(:final error) => error.message,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestExit(BuildContext context) async {
    final current = ref.read(themeAppearanceViewModelProvider).value;
    if (current?.submitting == true || _confirmingExit) return;
    if (current?.hasChanges == true) {
      _confirmingExit = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃未保存的修改？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      );
      _confirmingExit = false;
      if (discard != true || !context.mounted) return;
      ref.read(themeAppearanceViewModelProvider.notifier).discardChanges();
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _BackgroundSettings extends StatelessWidget {
  const _BackgroundSettings({required this.state, required this.notifier});

  final ThemeAppearanceState state;
  final ThemeAppearanceViewModel notifier;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('背景风格', style: textStyles.settingsTitle),
          const SizedBox(height: AppSpacing.space12),
          AppChoiceChipGroup<AppBackgroundStyle>(
            options: const [
              AppChoiceChipOption(value: AppBackgroundStyle.solid, label: '纯色'),
              AppChoiceChipOption(
                value: AppBackgroundStyle.singleGlow,
                label: '单色光晕',
              ),
              AppChoiceChipOption(
                value: AppBackgroundStyle.multiGlow,
                label: '多色光晕',
              ),
            ],
            selected: state.appearance.backgroundStyle,
            onChanged: notifier.setBackgroundStyle,
            enabled: !state.submitting,
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(switch (state.appearance.backgroundStyle) {
            AppBackgroundStyle.solid => '关闭光晕，使用页面底色。',
            AppBackgroundStyle.singleGlow => '背景基色从左上角柔和扩散。',
            AppBackgroundStyle.multiGlow => '背景基色与相邻色柔和交叠。',
          }, style: textStyles.listSupporting),
          if (state.appearance.backgroundStyle != AppBackgroundStyle.solid) ...[
            const SizedBox(height: AppSpacing.space16),
            _GradientSlider(
              label: '渐变深浅',
              value: state.appearance.gradientDepth,
              minimum: 0,
              onChanged: state.submitting ? null : notifier.setGradientDepth,
            ),
            const SizedBox(height: AppSpacing.space8),
            _GradientSlider(
              label: '渐变范围',
              value: state.appearance.gradientRange,
              minimum: AppAppearanceTokens.minGradientRange,
              onChanged: state.submitting ? null : notifier.setGradientRange,
            ),
          ],
        ],
      ),
    );
  }
}

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.label,
    required this.value,
    required this.minimum,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double minimum;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: textStyles.settingsTitle)),
            Text('${(value * 100).round()}%', style: textStyles.listSupporting),
          ],
        ),
        Slider(
          value: value,
          min: minimum,
          divisions: ((1 - minimum) * 100).round(),
          label: '${(value * 100).round()}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
