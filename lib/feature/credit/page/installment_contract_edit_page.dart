import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';

import '../../../core/money/money.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_contract_edit_state.dart';
import '../view_model/installment_contract_edit_view_model.dart';
import '../widget/installment_plan_summary_card.dart';
import '../widget/installment_schedule_editor.dart';
import '../view_model/loan_configuration_view_model.dart';
import 'loan_configuration_page.dart';

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
  TextEditingController? _nameController;

  @override
  void dispose() {
    _nameController?.dispose();
    super.dispose();
  }

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
    final nameController = _nameController ??= TextEditingController(
      text: contract.name,
    );

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
          if (loaded.metrics case final metrics?)
            InstallmentPlanSummaryCard(
              title: contract.name,
              metrics: metrics,
              contractStatus: contract.status,
            )
          else
            const Text('已保存合同指标加载失败，请稍后重试'),
          const SizedBox(height: AppSpacing.space12),
          AppFormSection(
            title: '合同配置',
            children: [
              AppPlainTextFormRow(
                label: '合同名称',
                controller: nameController,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入合同名称' : null,
              ),
              AppPlainValueRow(
                label: '借款日期',
                value: formatDateLabel(contract.borrowingDate),
                valueAlignment: AppPlainRowValueAlignment.start,
              ),
              AppPlainValueRow(
                label: '分期类型',
                value:
                    contract.sourceType == InstallmentSourceType.billConversion
                    ? '账单分期'
                    : '放款分期',
                valueAlignment: AppPlainRowValueAlignment.start,
              ),
              AppPlainValueRow(
                label: '本金',
                value: contract.principal.format(),
                valueAlignment: AppPlainRowValueAlignment.start,
              ),
              AppPlainSelectFormRow<String>(
                label: '分期配置',
                value: '${loaded.stageDraft.stages.length} 个阶段',
                placeholder: '点击配置',
                onTap: (_) => _configure(loaded),
              ),
              AppSubmitButton(label: '按配置重算', onPressed: _recalculate),
              if (!loaded.stagePlanPreviewed) const Text('修改配置不会自动重算还款计划。'),
            ],
          ),
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

  Future<void> _configure(InstallmentContractEditLoaded loaded) async {
    _formKey.currentState!.save();
    FocusScope.of(context).unfocus();
    final contract = loaded.contract;
    final initial = InstallmentConfigurationDraft(
      principal: contract.principal,
      borrowingDate: contract.borrowingDate,
      terms: loaded.stageDraft,
      basicInfoReadOnly: true,
    );
    final configuration = await Navigator.of(context)
        .push<InstallmentConfigurationDraft>(
          MaterialPageRoute(
            builder: (_) => LoanConfigurationPage(installment: initial),
          ),
        );
    if (!mounted || configuration == null) return;
    ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .applyConfiguration(configuration);
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
        .submit(nameText: _nameController?.text);
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
