import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/date_label.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/loan_configuration_view_model.dart';
import '../view_model/loan_prepayment_view_model.dart';
import '../widget/loan_configuration_entry.dart';
import 'loan_configuration_page.dart';
import 'loan_plan_page.dart';

class LoanPrepaymentPage extends ConsumerStatefulWidget {
  const LoanPrepaymentPage({super.key});
  @override
  ConsumerState<LoanPrepaymentPage> createState() => _LoanPrepaymentPageState();
}

class _LoanPrepaymentPageState extends ConsumerState<LoanPrepaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _paidController = TextEditingController();
  final _principalController = TextEditingController();

  @override
  void dispose() {
    _paidController.dispose();
    _principalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanPrepaymentViewModelProvider);
    final notifier = ref.read(loanPrepaymentViewModelProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '提前还款试算'),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  children: [
                    LoanConfigurationEntry(
                      label: '贷款配置',
                      configured: state.configuration != null,
                      onTap: () => _configure(notifier, state.configuration),
                    ),
                    const SizedBox(height: AppSpacing.space16),
                    AppFormSection(
                      title: '提前还款配置',
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space16,
                        vertical: AppSpacing.space8,
                      ),
                      children: [
                        AppPlainIntegerFormRow(
                          label: '已还期数',
                          controller: _paidController,
                          hintText: '从第 1 期起已还清的期数，留空为 0',
                          validator: (text) {
                            if (text == null || text.trim().isEmpty) {
                              return null;
                            }
                            final count = int.tryParse(text.trim());
                            if (count == null || count < 0) return '请输入非负整数';
                            final total =
                                state.configuration?.calculation.periods.length;
                            return total != null && count >= total
                                ? '已还期数必须少于 $total 期'
                                : null;
                          },
                        ),
                        DateTimePlainFormRow(
                          label: '提前还款日',
                          dateTime: state.date,
                          value: formatDateLabel(state.date),
                          onTap: (onSelected) async {
                            final date = await showAppDatePicker(
                              context: context,
                              initialDate: state.date,
                              title: '选择提前还款日期',
                            );
                            if (mounted && date != null) onSelected(date);
                          },
                          onChanged: (date) {
                            if (date != null) notifier.setDate(date);
                          },
                        ),
                        MoneyPlainFormRow(
                          label: '提前还本金',
                          controller: _principalController,
                          hintText: '本次提前归还的本金',
                          validator: validatePositiveMoneyText,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppSubmitButton(
                      label: '试算',
                      onPressed: state.configuration == null
                          ? null
                          : () => _simulate(notifier, state.date),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configure(
    LoanPrepaymentViewModel notifier,
    LoanConfiguration? initial,
  ) async {
    final configuration = await Navigator.of(context).push<LoanConfiguration>(
      MaterialPageRoute(
        builder: (_) =>
            LoanConfigurationPage(initial: initial, selection: true),
      ),
    );
    if (mounted && configuration != null) {
      notifier.setConfiguration(configuration);
    }
  }

  Future<void> _simulate(
    LoanPrepaymentViewModel notifier,
    DateTime date,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final outcome = await notifier.simulate(
      paidPeriodsText: _paidController.text,
      principalText: _principalController.text,
    );
    if (!mounted) return;
    switch (outcome) {
      case UiActionFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      case UiActionSuccess(:final value):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => LoanPlanPage.prepayment(
              simulation: value,
              prepaymentDate: date,
            ),
          ),
        );
    }
  }
}
