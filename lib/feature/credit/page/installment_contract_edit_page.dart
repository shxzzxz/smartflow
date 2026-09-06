import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';

import '../../../core/money/money.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_contract_edit_state.dart';
import '../view_model/installment_contract_edit_view_model.dart';
import '../widget/installment_plan_summary_card.dart';
import '../widget/installment_schedule_editor.dart';
import '../widget/installment_terms_editor.dart';
import '../widget/loan_basic_info_fields.dart';

class InstallmentContractEditPage extends ConsumerStatefulWidget {
  const InstallmentContractEditPage({required this.contractId, super.key});

  final String contractId;

  @override
  ConsumerState<InstallmentContractEditPage> createState() =>
      _InstallmentContractEditPageState();
}

class _InstallmentContractEditPageState
    extends ConsumerState<InstallmentContractEditPage> {
  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    final editAsync = ref.watch(
      installmentContractEditViewModelProvider(widget.contractId),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '编辑合同'),
            Expanded(
              child: switch (editAsync) {
                AsyncData(value: InstallmentContractEditLoaded loaded) =>
                  _buildBody(loaded),
                AsyncData(value: InstallmentContractEditNotFound()) =>
                  const Center(child: Text('合同不存在')),
                AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(InstallmentContractEditLoaded loaded) {
    final contract = loaded.contract;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space12,
          AppSpacing.space16,
          AppSpacing.space24,
        ),
        children: [
          AppFormSection(
            title: '贷款',
            children: [
              LoanBasicInfoFields.readOnly(
                principal: contract.principal,
                borrowingDate: contract.borrowingDate,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          if (loaded.metrics case final metrics?)
            InstallmentPlanSummaryCard(
              title: '已保存合同汇总',
              metrics: metrics,
              periodCount: contract.totalPeriods,
            )
          else
            const Text('已保存合同指标加载失败，请稍后重试'),
          const SizedBox(height: AppSpacing.space12),
          ...[
            AppPlainSwitchRow(
              label: '自定义本笔贷款',
              value: loaded.customRules,
              description: '关闭保留修改，只锁定阶段结构和计算规则',
              onChanged: ref
                  .read(
                    installmentContractEditViewModelProvider(
                      widget.contractId,
                    ).notifier,
                  )
                  .setCustomRules,
            ),
            InstallmentTermsEditor(
              value: loaded.stageDraft,
              borrowingDate: contract.borrowingDate,
              planAction: AppSubmitButton(
                label: '按参数重算并预览',
                onPressed: _recalculate,
              ),
              rulesEditable: loaded.customRules,
              onChanged: ref
                  .read(
                    installmentContractEditViewModelProvider(
                      widget.contractId,
                    ).notifier,
                  )
                  .setStageDraft,
            ),
            if (!loaded.stagePlanPreviewed)
              const Text('保存条款不会自动重算计划；需要时先点击按参数重算。'),
          ],
          const SizedBox(height: AppSpacing.space12),
          InstallmentScheduleEditor(
            draft: loaded.draft,
            manualPatched: loaded.manualPatchedPeriodNos,
            onApplyAmount: _applyAmount,
            onEditDate: _editScheduleDate,
          ),
          const SizedBox(height: AppSpacing.space20),
          AppSubmitButton(
            label: '保存',
            loading: loaded.submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _recalculate() async {
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    final outcome = await ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .recalculate();
    switch (outcome) {
      case UiActionFailure<void>(:final error):
        if (mounted) _showError(error.message);
      case UiActionSuccess<void>():
        break;
    }
  }

  void _applyAmount(
    InstallmentContractDraftRow row,
    InstallmentAmountField field,
    Money value,
  ) {
    ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .applyAmount(row, field, value);
  }

  Future<void> _editScheduleDate(InstallmentContractDraftRow row) async {
    if (row.status != InstallmentScheduleStatus.pending) return;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: row.date,
      title: '选择第 ${row.periodNo} 期还款日',
    );
    if (picked == null || !mounted) return;
    ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .editScheduleDate(row, picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    final outcome = await ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .submit();
    if (!mounted) return;
    switch (outcome) {
      case SubmitSuccess():
        context.pop();
      case SubmitFailure(:final error):
        _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
