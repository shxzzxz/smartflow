import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_date_picker_panel.dart';

const double _panelDialogMaxWidth = 336;

class AppMonthSelector extends StatelessWidget {
  const AppMonthSelector({
    required this.visibleMonth,
    required this.onPreviousMonth,
    required this.onMonthPressed,
    required this.onNextMonth,
    super.key,
  });

  final DateTime visibleMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onMonthPressed;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthArrowButton(
          icon: Icons.chevron_left,
          tooltip: '上个月',
          onPressed: onPreviousMonth,
        ),
        InkWell(
          onTap: onMonthPressed,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
              vertical: AppSpacing.space6,
            ),
            child: Text(
              '${visibleMonth.year}年${visibleMonth.month}月',
              style: context.appTextStyles.dateNavigationTitle,
            ),
          ),
        ),
        _MonthArrowButton(
          icon: Icons.chevron_right,
          tooltip: '下个月',
          onPressed: onNextMonth,
        ),
      ],
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: colors.onSurfaceVariant),
      iconSize: AppSpacing.space20,
      padding: const EdgeInsets.all(AppSpacing.space4),
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.space28,
        height: AppSpacing.space32,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

Future<DateTime?> showAppMonthPicker({
  required BuildContext context,
  required DateTime initialMonth,
  int firstYear = 2000,
  int lastYear = 2100,
  String title = '选择月份',
}) {
  return showDialog<DateTime>(
    context: context,
    builder:
        (context) => AppMonthPickerDialog(
          initialMonth: initialMonth,
          firstYear: firstYear,
          lastYear: lastYear,
          title: title,
        ),
  );
}

Future<int?> showAppYearPicker({
  required BuildContext context,
  required int initialYear,
  int firstYear = 2000,
  int lastYear = 2100,
  String title = '选择年份',
}) {
  return showDialog<int>(
    context: context,
    builder:
        (context) => AppYearPickerDialog(
          initialYear: initialYear,
          firstYear: firstYear,
          lastYear: lastYear,
          title: title,
        ),
  );
}

class AppMonthPickerDialog extends StatelessWidget {
  const AppMonthPickerDialog({
    required this.initialMonth,
    required this.firstYear,
    required this.lastYear,
    required this.title,
    super.key,
  });

  final DateTime initialMonth;
  final int firstYear;
  final int lastYear;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _PanelDialogShell(
      title: title,
      child: AppDatePickerPanel(
        granularity: AppDatePickerGranularity.month,
        initialValue: initialMonth,
        firstDate: DateTime(firstYear),
        lastDate: DateTime(lastYear, 12, 31),
        onSelected: (month) => Navigator.of(context).pop(month),
      ),
    );
  }
}

class AppYearPickerDialog extends StatelessWidget {
  const AppYearPickerDialog({
    required this.initialYear,
    required this.firstYear,
    required this.lastYear,
    required this.title,
    super.key,
  });

  final int initialYear;
  final int firstYear;
  final int lastYear;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _PanelDialogShell(
      title: title,
      child: AppDatePickerPanel(
        granularity: AppDatePickerGranularity.year,
        initialValue: DateTime(initialYear),
        firstDate: DateTime(firstYear),
        lastDate: DateTime(lastYear, 12, 31),
        onSelected: (year) => Navigator.of(context).pop(year.year),
      ),
    );
  }
}

/// 点选即回传的面板对话框外壳，无确认按钮，点击遮罩取消。
class _PanelDialogShell extends StatelessWidget {
  const _PanelDialogShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space24,
        vertical: AppSpacing.space24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _panelDialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space12,
            AppSpacing.space12,
            AppSpacing.space12,
            AppSpacing.space10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.appTextStyles.subsectionTitle,
              ),
              const SizedBox(height: AppSpacing.space6),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
