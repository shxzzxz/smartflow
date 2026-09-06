import 'package:flutter/material.dart';

import '../../application/credit/credit_query_api.dart';
import '../../core/money/money.dart';
import '../../feature/credit/presentation/installment_schedule_presentation.dart';
import '../../feature/credit/view_model/installment_schedule_draft.dart';
import '../../feature/credit/view_model/installment_terms_draft.dart';
import '../../feature/credit/widget/installment_plan_summary_card.dart';
import '../../feature/credit/widget/installment_schedule_editor.dart';
import '../../feature/credit/widget/installment_schedule_view.dart';
import '../../feature/credit/widget/installment_terms_editor.dart';
import '../../feature/credit/widget/loan_basic_info_fields.dart';
import '../token/spacing.dart';
import '../widget/app_datetime_picker.dart';
import '../widget/app_form_section.dart';
import '../widget/app_plain_form_row.dart';
import '../widget/app_submit_button.dart';

class LoanBasicInfoPreview extends StatefulWidget {
  const LoanBasicInfoPreview({super.key});
  @override
  State<LoanBasicInfoPreview> createState() => _LoanBasicInfoPreviewState();
}

class _LoanBasicInfoPreviewState extends State<LoanBasicInfoPreview> {
  final principal = TextEditingController(text: '12000');
  var date = DateTime(2026, 1, 10);
  @override
  void dispose() {
    principal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    child: AppFormSection(
      children: [
        LoanBasicInfoFields(
          principalController: principal,
          borrowingDate: date,
          onBorrowingDateChanged: (value) => setState(() => date = value),
        ),
        LoanBasicInfoFields.readOnly(
          principal: const Money(minorUnits: 1200000),
          borrowingDate: date,
        ),
      ],
    ),
  );
}

class InstallmentTermsPreview extends StatefulWidget {
  const InstallmentTermsPreview({super.key});
  @override
  State<InstallmentTermsPreview> createState() =>
      _InstallmentTermsPreviewState();
}

class _InstallmentTermsPreviewState extends State<InstallmentTermsPreview> {
  final formKey = GlobalKey<FormState>();
  var terms = InstallmentTermsDraft.loan(DateTime(2026, 1, 10));
  var rulesEditable = true;
  var product = false;
  var validated = false;
  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(
      children: [
        AppPlainSwitchRow(
          label: '产品规则模式',
          value: product,
          onChanged: (value) => setState(() => product = value),
        ),
        AppPlainSwitchRow(
          label: '允许修改规则',
          value: rulesEditable,
          onChanged: (value) => setState(() => rulesEditable = value),
        ),
        InstallmentTermsEditor(
          value: terms,
          mode: product
              ? InstallmentTermsEditorMode.product
              : InstallmentTermsEditorMode.contract,
          borrowingDate: DateTime(2026, 1, 10),
          rulesEditable: rulesEditable,
          onChanged: (value) => setState(() {
            terms = value;
            validated = false;
          }),
          planAction: AppSubmitButton(
            label: '校验输入',
            onPressed: () {
              setState(() => validated = formKey.currentState!.validate());
            },
          ),
        ),
        if (validated) const Text('输入校验通过'),
      ],
    ),
  );
}

class InstallmentSchedulePreview extends StatelessWidget {
  const InstallmentSchedulePreview({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      InstallmentScheduleView(items: []),
      SizedBox(height: AppSpacing.space12),
      _SampleScheduleView(),
    ],
  );
}

class _SampleScheduleView extends StatelessWidget {
  const _SampleScheduleView();
  @override
  Widget build(BuildContext context) => InstallmentScheduleView(
    items: [
      for (var i = 1; i <= 2; i++)
        InstallmentScheduleViewItem(
          id: 'sample-$i',
          periodNo: i,
          date: DateTime(2026, i + 1, 10),
          principal: const Money(minorUnits: 600000),
          interest: const Money(minorUnits: 6000),
          fee: Money.zero(),
          remainingPrincipal: Money(minorUnits: i == 1 ? 600000 : 0),
          status: i == 1
              ? InstallmentScheduleStatus.paid
              : InstallmentScheduleStatus.pending,
          recalculated: i == 2,
        ),
    ],
  );
}

class InstallmentSummaryPreview extends StatelessWidget {
  const InstallmentSummaryPreview({super.key});
  @override
  Widget build(BuildContext context) => const InstallmentPlanSummaryCard(
    principal: Money(minorUnits: 1200000),
    periodCount: 2,
    metrics: ContractMetrics(
      monthlyIrr: null,
      nominalApr: null,
      effectiveApr: null,
      totalRepayment: Money(minorUnits: 1212000),
      totalInterest: Money(minorUnits: 12000),
      totalFee: Money(minorUnits: 0),
      converged: false,
      unavailableReason: ContractMetricsUnavailableReason.noRateSolution,
    ),
  );
}

class InstallmentScheduleEditorPreview extends StatefulWidget {
  const InstallmentScheduleEditorPreview({super.key});
  @override
  State<InstallmentScheduleEditorPreview> createState() =>
      _InstallmentScheduleEditorPreviewState();
}

class _InstallmentScheduleEditorPreviewState
    extends State<InstallmentScheduleEditorPreview> {
  final formKey = GlobalKey<FormState>();
  final edited = <int>{};
  var rows = [
    for (var i = 1; i <= 2; i++)
      InstallmentContractDraftRow(
        scheduleId: 'sample-$i',
        periodNo: i,
        date: DateTime(2026, i + 1, 10),
        principal: const Money(minorUnits: 600000),
        interest: const Money(minorUnits: 6000),
        fee: const Money(minorUnits: 0),
        status: i == 1
            ? InstallmentScheduleStatus.paid
            : InstallmentScheduleStatus.pending,
      ),
  ];
  void replace(InstallmentContractDraftRow next) => setState(() {
    rows = [for (final row in rows) row.periodNo == next.periodNo ? next : row];
    edited.add(next.periodNo);
  });
  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(
      children: [
        InstallmentScheduleEditor(
          draft: rows,
          manualPatched: edited,
          onApplyAmount: (row, field, value) => replace(switch (field) {
            InstallmentAmountField.principal => row.copyWith(principal: value),
            InstallmentAmountField.interest => row.copyWith(interest: value),
            InstallmentAmountField.fee => row.copyWith(fee: value),
          }),
          onEditDate: (row) async {
            final date = await showAppDatePicker(
              context: context,
              initialDate: row.date,
            );
            if (mounted && date != null) replace(row.copyWith(date: date));
          },
        ),
        const SizedBox(height: AppSpacing.space12),
        AppSubmitButton(
          label: '保存示例',
          onPressed: () {
            if (formKey.currentState!.validate()) formKey.currentState!.save();
          },
        ),
      ],
    ),
  );
}
