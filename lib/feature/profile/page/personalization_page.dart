import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_appearance_settings.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/appearance.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_settings_row.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/personalization_view_model.dart';
import '../widget/personalization_color_picker.dart';
import '../widget/personalization_preview.dart';
import '../../../design_system/widget/app_scaffold.dart';

class PersonalizationPage extends ConsumerStatefulWidget {
  const PersonalizationPage({super.key});

  @override
  ConsumerState<PersonalizationPage> createState() =>
      _PersonalizationPageState();
}

class _PersonalizationPageState extends ConsumerState<PersonalizationPage> {
  bool _confirmingExit = false;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(personalizationViewModelProvider);
    final state = asyncState.value;
    final notifier = ref.read(personalizationViewModelProvider.notifier);
    final enabled = state != null && !asyncState.isLoading && !state.submitting;
    return PopScope<Object?>(
      canPop: state?.hasChanges != true && state?.submitting != true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: DefaultTabController(
        length: 3,
        initialIndex: 1,
        child: AppScaffold(
          body: SafeArea(
            child: Column(
              children: [
                AppPageHeader(
                  title: '个性化设置',
                  onBack: _requestExit,
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
                        title: '无法加载个性化设置',
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
    );
  }

  Widget _buildEditor(
    BuildContext context,
    PersonalizationState state,
    PersonalizationViewModel notifier,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    return LayoutBuilder(
      builder: (context, constraints) {
        final requestedHeight = math.max(
          constraints.maxHeight *
              AppComponentTokens.personalizationPanelHeightFactor,
          AppComponentTokens.personalizationPanelMinHeight,
        );
        final panelHeight = math.min(
          constraints.maxHeight,
          math.max(
            AppComponentTokens.controlMinHeight,
            math.min(
              requestedHeight,
              constraints.maxHeight -
                  AppComponentTokens.personalizationPreviewMinHeight,
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space8,
            AppSpacing.space16,
            AppSpacing.space16,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('样式预览', style: textStyles.listSupporting),
                  ),
                  Text(
                    state.hasChanges ? '未保存' : '当前样式',
                    style: textStyles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.radiusXl),
                  child: PersonalizationPreview(
                    key: const ValueKey('personalization-preview'),
                    appearance: state.appearance,
                    showAddTransactionFab: state.showAddTransactionFab,
                    settings: state.savedSettings,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              SizedBox(
                key: const ValueKey('personalization-editor'),
                height: math.max(
                  AppComponentTokens.controlMinHeight,
                  panelHeight - AppSpacing.space24,
                ),
                child: AppSurface(
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: '布局'),
                          Tab(text: '颜色'),
                          Tab(text: '外观'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            ListView(
                              padding: const EdgeInsets.all(AppSpacing.space16),
                              children: [
                                AppSettingsSwitchRow(
                                  label: '记账悬浮按钮',
                                  value: state.showAddTransactionFab,
                                  enabled: !state.submitting,
                                  onChanged: notifier.setShowAddTransactionFab,
                                ),
                              ],
                            ),
                            _ColorsPanel(state: state, notifier: notifier),
                            _AppearancePanel(state: state, notifier: notifier),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final outcome = await ref
        .read(personalizationViewModelProvider.notifier)
        .save();
    if (!mounted) return;
    final message = switch (outcome) {
      UiActionSuccess() => '个性化设置已保存',
      UiActionFailure(:final error) => error.message,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestExit() async {
    final current = ref.read(personalizationViewModelProvider).value;
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
      if (discard != true || !mounted) return;
      ref.read(personalizationViewModelProvider.notifier).discardChanges();
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _ColorsPanel extends StatelessWidget {
  const _ColorsPanel({required this.state, required this.notifier});

  final PersonalizationState state;
  final PersonalizationViewModel notifier;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.space16),
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final columns =
              constraints.maxWidth >=
                  AppComponentTokens.personalizationColorTileMinWidth *
                          textScale *
                          4 +
                      AppSpacing.space8 * 3
              ? 4
              : 2;
          final tileWidth =
              (constraints.maxWidth - AppSpacing.space8 * (columns - 1)) /
              columns;
          return Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space8,
            children: [
              SizedBox(
                width: tileWidth,
                child: _ColorTile(
                  label: '主题色',
                  value: state.appearance.primaryColor,
                  onChanged: state.submitting ? null : notifier.setPrimaryColor,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _ColorTile(
                  label: '背景基色',
                  value: state.appearance.backgroundSeedColor,
                  onChanged: state.submitting
                      ? null
                      : notifier.setBackgroundSeedColor,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _ColorTile(
                  label: '收入颜色',
                  value: state.appearance.incomeColor,
                  onChanged: state.submitting ? null : notifier.setIncomeColor,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _ColorTile(
                  label: '支出颜色',
                  value: state.appearance.expenseColor,
                  onChanged: state.submitting ? null : notifier.setExpenseColor,
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      onTap: onChanged == null
          ? null
          : () => showPersonalizationColorPicker(
              context: context,
              title: label,
              color: value,
              onChanged: onChanged!,
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppComponentTokens.personalizationColorSwatchSize,
              height: AppComponentTokens.personalizationColorSwatchSize,
              decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: AppComponentTokens.outlineWidth,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              label,
              style: textStyles.settingsTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                style: textStyles.listSupporting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel({required this.state, required this.notifier});

  final PersonalizationState state;
  final PersonalizationViewModel notifier;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
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
