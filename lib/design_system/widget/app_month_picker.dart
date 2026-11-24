import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_text_styles.dart';
import '../token/header.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_date_picker_panel.dart';
import 'app_page_header.dart';

const double _panelDialogMaxWidth = 336;

/// 居中的 `< YYYY年MM月 >`；点击箭头或左右滑动切换，点击月份选择。
class AppMonthSelector extends StatefulWidget {
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
  State<AppMonthSelector> createState() => _AppMonthSelectorState();
}

class _AppMonthSelectorState extends State<AppMonthSelector> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final month = widget.visibleMonth;
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: '上个月'): widget.onPreviousMonth,
        const CustomSemanticsAction(label: '下个月'): widget.onNextMonth,
      },
      child: GestureDetector(
        onHorizontalDragStart: (_) => _dragDistance = 0,
        onHorizontalDragUpdate: (details) =>
            _dragDistance += details.primaryDelta ?? 0,
        onHorizontalDragEnd: (_) {
          if (_dragDistance.abs() < AppHeaderTokens.monthSwipeDistance) return;
          if (_dragDistance < 0) {
            widget.onNextMonth();
          } else {
            widget.onPreviousMonth();
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppHeaderIconButton(
              icon: RemixIcons.arrow_left_s_line,
              compact: true,
              tooltip: '上个月',
              onPressed: widget.onPreviousMonth,
            ),
            Flexible(
              child: Tooltip(
                message: '选择月份',
                child: InkWell(
                  onTap: widget.onMonthPressed,
                  borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space0,
                      vertical: AppSpacing.space8,
                    ),
                    child: Text(
                      '${month.year}年${month.month.toString().padLeft(2, '0')}月',
                      style: context.appTextStyles.dateNavigationTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            AppHeaderIconButton(
              icon: RemixIcons.arrow_right_s_line,
              compact: true,
              tooltip: '下个月',
              onPressed: widget.onNextMonth,
            ),
          ],
        ),
      ),
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
    builder: (context) => AppMonthPickerDialog(
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
    builder: (context) => AppYearPickerDialog(
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
