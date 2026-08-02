import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/list.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_surface.dart';
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
                _SettingsSwitchRow(
                  label: '记账悬浮按钮',
                  description: '在首页右下角显示快速记账按钮，关闭后仍可下拉新增交易',
                  value: settings.showAddTransactionFab,
                  onChanged: notifier.setShowAddTransactionFab,
                ),
                _SettingsSwitchRow(
                  label: '导航栏文字',
                  description: '在底部导航图标下方显示文字标签',
                  value: settings.showBottomNavLabels,
                  onChanged: notifier.setShowBottomNavLabels,
                ),
                AppPlainSelectFormRow<PullToCreateSensitivity>(
                  label: '下拉新增交易',
                  value: settings.pullToCreateSensitivity,
                  valueText: _pullToCreateSensitivityLabel(
                    settings.pullToCreateSensitivity,
                  ),
                  placeholder: '标准',
                  supportingText: '调整首页下拉多远后松开即可新增交易',
                  onTap: (onSelected) async {
                    final selected = await _showPullToCreateSensitivitySheet(
                      context,
                      settings.pullToCreateSensitivity,
                    );
                    if (selected == null) return;

                    onSelected(selected);
                    await notifier.setPullToCreateSensitivity(selected);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _pullToCreateSensitivityLabel(PullToCreateSensitivity sensitivity) {
  return switch (sensitivity) {
    PullToCreateSensitivity.sensitive => '灵敏',
    PullToCreateSensitivity.standard => '标准',
    PullToCreateSensitivity.cautious => '稳妥',
  };
}

String _pullToCreateSensitivityDescription(
  PullToCreateSensitivity sensitivity,
) {
  return switch (sensitivity) {
    PullToCreateSensitivity.sensitive => '短距离下拉后即可新增交易',
    PullToCreateSensitivity.standard => '适中的下拉距离',
    PullToCreateSensitivity.cautious => '更长的下拉距离，减少误触',
  };
}

Future<PullToCreateSensitivity?> _showPullToCreateSensitivitySheet(
  BuildContext context,
  PullToCreateSensitivity selected,
) {
  return showModalBottomSheet<PullToCreateSensitivity>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sensitivity in PullToCreateSensitivity.values)
                ListTile(
                  leading: Icon(
                    sensitivity == selected
                        ? RemixIcons.checkbox_circle_fill
                        : RemixIcons.checkbox_blank_circle_line,
                  ),
                  title: Text(_pullToCreateSensitivityLabel(sensitivity)),
                  subtitle: Text(
                    _pullToCreateSensitivityDescription(sensitivity),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(sensitivity),
                ),
            ],
          ),
        ),
  );
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

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space10,
        AppSpacing.space12,
        AppSpacing.space10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.appTextStyles.formValue),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  description,
                  style: context.appTextStyles.listSupporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
