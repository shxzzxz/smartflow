import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import 'loan_comparison_page.dart';
import 'loan_configuration_page.dart';
import 'loan_prepayment_page.dart';

class LoanCalculatorPage extends StatelessWidget {
  const LoanCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const AppPageHeader(title: '贷款计算器'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.space16),
              children: [
                _entry(
                  context,
                  '贷款试算',
                  '配置贷款，查看成本和逐期还款计划',
                  RemixIcons.calculator_line,
                  const LoanConfigurationPage(),
                ),
                const SizedBox(height: AppSpacing.space12),
                _entry(
                  context,
                  '贷款比较',
                  '对比两个方案的还款总额和实际年化',
                  RemixIcons.scales_3_line,
                  const LoanComparisonPage(),
                ),
                const SizedBox(height: AppSpacing.space12),
                _entry(
                  context,
                  '提前还款试算',
                  '查看提前还本金后的利息和还款计划',
                  RemixIcons.calendar_check_line,
                  const LoanPrepaymentPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _entry(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Widget page,
  ) => AppSurface(
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(RemixIcons.arrow_right_s_line),
      onTap: () => Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => page)),
    ),
  );
}
