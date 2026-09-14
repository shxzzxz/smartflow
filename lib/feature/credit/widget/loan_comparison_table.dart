import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../presentation/loan_comparison_presentation.dart';

class LoanComparisonTable extends StatelessWidget {
  const LoanComparisonTable({
    required this.rows,
    this.firstLabel = '配置一',
    this.secondLabel = '配置二',
    this.differenceLabel = '差值',
    super.key,
  });
  final List<LoanComparisonRowPresentation> rows;
  final String firstLabel, secondLabel, differenceLabel;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    Widget cell(String text, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space12,
      ),
      child: Text(text, style: header ? styles.formLabel : styles.formValue),
    );
    return AppSurface(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.15),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
          3: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        children: [
          TableRow(
            children: [
              cell('指标', header: true),
              cell(firstLabel, header: true),
              cell(secondLabel, header: true),
              cell(differenceLabel, header: true),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                cell(row.label, header: true),
                cell(row.firstValue),
                cell(row.secondValue),
                cell(row.difference),
              ],
            ),
        ],
      ),
    );
  }
}
