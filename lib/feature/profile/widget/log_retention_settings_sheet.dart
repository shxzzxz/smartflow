import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/shared/log_retention_store.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../view_model/log_viewer_view_model.dart';

Future<void> showLogRetentionSettingsSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _LogRetentionSettingsSheet(),
  );
}

class _LogRetentionSettingsSheet extends ConsumerWidget {
  const _LogRetentionSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final settings =
        ref.watch(logRetentionSettingsViewModelProvider).value ??
        const LogRetentionSettings();
    final notifier = ref.read(logRetentionSettingsViewModelProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space20,
          0,
          AppSpacing.space20,
          AppSpacing.space20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('清理设置', style: textStyles.sectionTitleStrong),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '日志按天或达到 1 MiB 自动分卷；保留天数和文件数同时生效，调整后立即清理。',
              style: textStyles.listSupporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            _RetentionOptionRow(
              label: '保留天数',
              options: const [
                AppSegment(value: 7, label: '7 天'),
                AppSegment(value: 14, label: '14 天'),
                AppSegment(value: 30, label: '30 天'),
              ],
              selected: settings.maxFileAgeDays,
              onChanged: notifier.setMaxFileAgeDays,
            ),
            const SizedBox(height: AppSpacing.space12),
            _RetentionOptionRow(
              label: '保留文件数',
              options: const [
                AppSegment(value: 50, label: '50 个'),
                AppSegment(value: 100, label: '100 个'),
                AppSegment(value: 200, label: '200 个'),
              ],
              selected: _displayedFileCount(settings.maxFiles),
              onChanged: notifier.setMaxFiles,
            ),
          ],
        ),
      ),
    );
  }
}

int _displayedFileCount(int value) {
  return switch (value) {
    50 || 100 || 200 => value,
    _ => 100,
  };
}

class _RetentionOptionRow extends StatelessWidget {
  const _RetentionOptionRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<AppSegment<int>> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: context.appTextStyles.settingsTitle),
        ),
        const SizedBox(width: AppSpacing.space12),
        AppSegmentedControl<int>(
          segments: options,
          selected: selected,
          size: AppSegmentedControlSize.small,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
