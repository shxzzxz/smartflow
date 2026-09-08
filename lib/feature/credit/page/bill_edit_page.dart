import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';

import '../../../core/time/date_label.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/bill_edit_form_state.dart';
import '../view_model/bill_edit_view_model.dart';

class BillEditPage extends ConsumerStatefulWidget {
  const BillEditPage({required this.billId, super.key});

  final String billId;

  @override
  ConsumerState<BillEditPage> createState() => _BillEditPageState();
}

class _BillEditPageState extends ConsumerState<BillEditPage> {
  Future<void> _pickStartDate(
    DateTime current,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current,
      title: '选择消费统计起始日',
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  Future<void> _pickBillingDate(
    DateTime current,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current,
      title: '选择消费统计结束日',
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(billEditViewModelProvider(widget.billId).notifier)
        .submit();
    if (!mounted) return;
    switch (outcome) {
      case SubmitSuccess():
        context.pop(true);
      case SubmitFailure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：${error.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(billEditViewModelProvider(widget.billId));
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '编辑消费统计区间'),
            Expanded(
              child: switch (asyncState) {
                AsyncData(value: final state) when state.loaded => _buildForm(
                  state,
                ),
                AsyncData() => const Center(child: Text('账单不存在或暂无消费明细')),
                AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BillEditFormState state) {
    final notifier = ref.read(
      billEditViewModelProvider(widget.billId).notifier,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space12,
        AppSpacing.space12,
        AppSpacing.space12,
        AppSpacing.space24,
      ),
      children: [
        AppFormSection(
          title: '消费统计区间',
          description: '使用闭区间，结束日必须仍在原账单月份；分期明细不受此编辑影响。',
          children: [
            DateTimePlainFormRow(
              label: '统计起始日',
              dateTime: state.startDate,
              value: formatDateLabel(state.startDate!),
              onTap: (onSelected) =>
                  _pickStartDate(state.startDate!, onSelected),
              onChanged: (value) {
                if (value != null) notifier.setStartDate(value);
              },
            ),
            DateTimePlainFormRow(
              label: '统计结束日',
              dateTime: state.billingDate,
              value: formatDateLabel(state.billingDate!),
              onTap: (onSelected) =>
                  _pickBillingDate(state.billingDate!, onSelected),
              onChanged: (value) {
                if (value != null) notifier.setBillingDate(value);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space20),
        AppSubmitButton(
          label: '保存',
          loading: state.submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
