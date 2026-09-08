import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../presentation/loan_comparison_presentation.dart';
import '../view_model/loan_comparison_view_model.dart';
import '../view_model/loan_configuration_view_model.dart';
import '../widget/loan_configuration_entry.dart';
import 'loan_configuration_page.dart';

class LoanComparisonPage extends ConsumerWidget {
  const LoanComparisonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loanComparisonViewModelProvider);
    final notifier = ref.read(loanComparisonViewModelProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '贷款比较'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.space16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LoanConfigurationEntry(
                          label: '配置一',
                          configured: state.first != null,
                          onTap: () =>
                              _configure(context, notifier, 0, state.first),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space12),
                      Expanded(
                        child: LoanConfigurationEntry(
                          label: '配置二',
                          configured: state.second != null,
                          onTap: () =>
                              _configure(context, notifier, 1, state.second),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: state.first == null
                          ? null
                          : notifier.copyFirstToSecond,
                      child: const Text('复制配置一到配置二'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Text('总体比较', style: context.appTextStyles.dateSectionTitle),
                  const SizedBox(height: AppSpacing.space8),
                  _ComparisonTable(first: state.first, second: state.second),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configure(
    BuildContext context,
    LoanComparisonViewModel notifier,
    int index,
    LoanConfiguration? initial,
  ) async {
    final configuration = await Navigator.of(context).push<LoanConfiguration>(
      MaterialPageRoute(
        builder: (_) =>
            LoanConfigurationPage(initial: initial, selection: true),
      ),
    );
    if (context.mounted && configuration != null) {
      notifier.setConfiguration(index, configuration);
    }
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.first, required this.second});
  final LoanConfiguration? first, second;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final rows = presentLoanComparison(first: first, second: second);
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
              cell('配置一', header: true),
              cell('配置二', header: true),
              cell('差值', header: true),
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
