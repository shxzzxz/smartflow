import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../presentation/loan_comparison_presentation.dart';
import '../view_model/loan_comparison_view_model.dart';
import '../view_model/loan_configuration_view_model.dart';
import '../widget/loan_configuration_entry.dart';
import '../widget/loan_comparison_table.dart';
import 'loan_configuration_page.dart';

class LoanComparisonPage extends ConsumerWidget {
  const LoanComparisonPage({this.initial, super.key});
  final LoanConfiguration? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = loanComparisonViewModelProvider(initial: initial);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
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
                  LoanComparisonTable(
                    rows: presentLoanComparison(
                      first: state.first,
                      second: state.second,
                    ),
                  ),
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
