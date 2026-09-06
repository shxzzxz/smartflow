import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/bill_repayment_allocation.dart';
import '../presentation/installment_schedule_presentation.dart';
import '../view_model/bill_conversion_installment_form_view_model.dart';
import '../widget/installment_plan_summary_card.dart';
import '../widget/installment_schedule_view.dart';
import '../widget/installment_terms_editor.dart';
import '../widget/loan_basic_info_fields.dart';

class BillConversionInstallmentFormPage extends ConsumerStatefulWidget {
  const BillConversionInstallmentFormPage({required this.billId, super.key});

  final String billId;

  @override
  ConsumerState<BillConversionInstallmentFormPage> createState() =>
      _BillConversionInstallmentFormPageState();
}

class _BillConversionInstallmentFormPageState
    extends ConsumerState<BillConversionInstallmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _noteController = TextEditingController();
  bool _controllersHydrated = false;

  @override
  void dispose() {
    _principalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = billConversionInstallmentFormViewModelProvider(
      widget.billId,
    );
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '账单分期'),
            Expanded(
              child: switch (asyncState) {
                AsyncData(value: final state) => _buildState(provider, state),
                AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildState(
    BillConversionInstallmentFormViewModelProvider provider,
    BillConversionInstallmentFormState state,
  ) {
    return switch (state) {
      BillConversionInstallmentLoaded() => _buildForm(provider, state),
      BillConversionInstallmentNotFound() => const Center(child: Text('账单不存在')),
      BillConversionInstallmentNotEligible() => const Center(
        child: Text('只有已出账账单可以发起账单分期'),
      ),
      BillConversionInstallmentNoPending() => const Center(
        child: Text('账单没有可分期消费明细'),
      ),
    };
  }

  Widget _buildForm(
    BillConversionInstallmentFormViewModelProvider provider,
    BillConversionInstallmentLoaded state,
  ) {
    _hydrateControllers(state);
    final notifier = ref.read(provider.notifier);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space18,
          AppSpacing.space16,
          AppSpacing.space24,
        ),
        children: [
          AppFormSection(
            title: '分期设置',
            children: [
              AppPlainValueRow(
                label: '账单',
                value: _periodLabel(state.summary.period),
              ),
              AppPlainValueRow(
                label: '可分期本金',
                value: state.convertiblePrincipal.format(),
              ),
              LoanBasicInfoFields(
                principalController: _principalController,
                borrowingDate: state.borrowingDate,
                onBorrowingDateChanged: notifier.setBorrowingDate,
              ),
              DropdownPlainFormRow<BillRepaymentAllocationMode>(
                label: '分摊方式',
                value: state.allocationMode,
                items: billRepaymentAllocationModeItems,
                onChanged: notifier.setAllocationMode,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          InstallmentTermsEditor(
            value: state.termsDraft,
            onChanged: notifier.setTermsDraft,
            borrowingDate: state.borrowingDate,
            planAction: AppSubmitButton(
              label: '预览还款计划',
              onPressed: () => _preview(notifier),
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          AppFormSection(
            children: [NotePlainFormRow(controller: _noteController)],
          ),
          const SizedBox(height: AppSpacing.space24),
          AppSubmitButton(
            label: '创建分期',
            loading: state.submitting,
            onPressed: () => _submit(provider),
          ),
        ],
      ),
    );
  }

  Future<void> _preview(BillConversionInstallmentFormViewModel notifier) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await notifier.preview(_principalController.text);
    if (!mounted) return;
    switch (outcome) {
      case UiActionFailure(:final error):
        _showError(error.message);
      case UiActionSuccess(:final value):
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.75,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.space16),
                children: [
                  InstallmentPlanSummaryCard(
                    metrics: value.metrics,
                    principal: value.totalPrincipal,
                    periodCount: value.periods.length,
                    stages: value.stages,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  InstallmentScheduleView(
                    items: calculationScheduleItems(
                      value.periods,
                      stages: value.stages,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Future<void> _submit(
    BillConversionInstallmentFormViewModelProvider provider,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref
        .read(provider.notifier)
        .submit(
          principalText: _principalController.text,
          noteText: _noteController.text,
        );
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess<String>(:final value):
        context.pushReplacement('/installments/$value');
      case UiActionFailure<String>(:final error):
        _showError(error.message);
    }
  }

  void _hydrateControllers(BillConversionInstallmentLoaded state) {
    if (_controllersHydrated) return;
    syncTextControllerText(_principalController, state.principalText);
    _controllersHydrated = true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

const List<DropdownMenuItem<BillRepaymentAllocationMode>>
billRepaymentAllocationModeItems = [
  DropdownMenuItem(
    value: BillRepaymentAllocationMode.fifo,
    child: Text('FIFO'),
  ),
  DropdownMenuItem(value: BillRepaymentAllocationMode.equal, child: Text('均摊')),
];

String _periodLabel(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月账单';
}
