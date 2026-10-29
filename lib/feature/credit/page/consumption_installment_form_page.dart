import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../../widget/business/account/account_picker_sheet.dart';
import '../../../widget/business/category/category_grid_picker.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../transaction/widget/transaction_allocation_fields.dart';
import '../view_model/installment_terms_draft.dart';
import '../widget/installment_terms_editor.dart';

class ConsumptionInstallmentFormPage extends ConsumerStatefulWidget {
  const ConsumptionInstallmentFormPage({super.key});

  @override
  ConsumerState<ConsumptionInstallmentFormPage> createState() =>
      _ConsumptionInstallmentFormPageState();
}

class _ConsumptionInstallmentFormPageState
    extends ConsumerState<ConsumptionInstallmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _occurredAt = DateTime.now();
  late DateTime _borrowingDate = DateTime(
    _occurredAt.year,
    _occurredAt.month,
    _occurredAt.day,
  );
  late InstallmentTermsDraft _terms = InstallmentTermsDraft.loan(
    _borrowingDate,
  );
  String? _categoryRootId;
  String? _categoryId;
  String? _liabilityAccountId;
  String? _productName;
  List<AccountAmountAllocation> _downPayments = const [];
  bool _submitting = false;
  bool _borrowingDateEdited = false;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryTreeProvider(AccountType.expense));
    final funds = ref.watch(
      accountsForSelectionPurposeProvider(AccountSelectionPurpose.fund),
    );
    final liabilities = ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentTarget,
      ),
    );
    final error = categories.error ?? funds.error ?? liabilities.error;
    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const AppPageHeader(title: '消费分期'),
              Expanded(child: Center(child: Text('加载失败：$error'))),
            ],
          ),
        ),
      );
    }
    if (!categories.hasValue || !funds.hasValue || !liabilities.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final fundAccounts = funds.requireValue;
    final creditAccounts = [
      for (final account in liabilities.requireValue)
        if (account.profileKey == AccountProfileKind.credit.key) account,
    ];
    final selectedCredit = _findAccount(creditAccounts, _liabilityAccountId);
    final amount = Money.tryParse(_amountController.text) ?? Money.zero();
    final downPaymentTotal = sumAllocations(_downPayments);
    final financed = amount.minorUnits > downPaymentTotal.minorUnits
        ? amount - downPaymentTotal
        : Money.zero();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '消费分期'),
            Expanded(
              child: Form(
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
                      title: '购买',
                      children: [
                        AppPlainTextFormRow(
                          label: '成交价',
                          controller: _amountController,
                          hintText: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [moneyInputFormatter],
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final money = Money.tryParse(value?.trim() ?? '');
                            return money == null || money.minorUnits <= 0
                                ? '请输入有效成交价'
                                : null;
                          },
                        ),
                        AppPlainFormRow(
                          label: '交易时间',
                          requiredIndicator: true,
                          onTap: _pickOccurredAt,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _dateText(_occurredAt),
                              style: context.appTextStyles.formValue,
                            ),
                          ),
                        ),
                        AppPlainTextFormRow(
                          label: '名称',
                          controller: _nameController,
                          hintText: '选填，例如手机',
                        ),
                        AppPlainTextFormRow(
                          label: '备注',
                          controller: _noteController,
                          hintText: '选填',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    AppFormSection(
                      title: '支出分类',
                      children: [
                        CategoryGridPicker(
                          nodes: categories.requireValue,
                          selectedRootId: _categoryRootId,
                          selectedCategoryId: _categoryId,
                          emptyLabel: '尚未创建支出分类',
                          onRootSelected: (category) => setState(() {
                            _categoryRootId = category.id;
                            _categoryId = category.id;
                          }),
                          onChildSelected: (root, child) => setState(() {
                            _categoryRootId = root.id;
                            _categoryId = child.id;
                          }),
                          onAddRoot: () => _openCategoryForm(),
                          onAddChild: (rootId) =>
                              _openCategoryForm(parentId: rootId),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    TransactionAllocationAmountFields(
                      title: '首付款',
                      allocations: _downPayments,
                      options: transactionAllocationOptionsForAccounts(
                        fundAccounts,
                      ),
                      maximumByAccountId: {
                        for (final account in fundAccounts) account.id: amount,
                      },
                      onChanged: (allocations) =>
                          setState(() => _downPayments = allocations),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    AppSurface(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '首付款 ${downPaymentTotal.format()}',
                                style: context.appTextStyles.listSupporting,
                              ),
                            ),
                            Text(
                              '融资本金 ${financed.format()}',
                              style: context.appTextStyles.formValueEmphasis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    AppFormSection(
                      title: '融资与还款',
                      children: [
                        AppPlainSelectFormRow<String>(
                          label: '信用账户',
                          value: selectedCredit?.name,
                          placeholder: '请选择',
                          onTap: (_) => _pickCreditAccount(creditAccounts),
                        ),
                        AppPlainFormRow(
                          label: '合同借款日',
                          onTap: _pickBorrowingDate,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _dateText(_borrowingDate),
                              style: context.appTextStyles.formValue,
                            ),
                          ),
                        ),
                        AppPlainSelectFormRow<String>(
                          label: '产品模板',
                          value: _productName,
                          placeholder: '请选择',
                          onTap: (_) => _pickProduct(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space12),
                    InstallmentTermsEditor(
                      value: _terms,
                      onChanged: (value) => setState(() => _terms = value),
                      borrowingDate: _borrowingDate,
                      showAdvanced: true,
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppSubmitButton(
                      label: '创建消费分期',
                      loading: _submitting,
                      onPressed: _submit,
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

  Future<void> _pickOccurredAt() async {
    final selected = await showAppDateTimePicker(
      context: context,
      initialDateTime: _occurredAt,
      title: '选择交易时间',
    );
    if (selected == null || !mounted) return;
    final oldDefault = IntervalRepaymentDates.addMonthsClamped(
      _borrowingDate,
      1,
    );
    final first = _terms.stages.first;
    setState(() {
      _occurredAt = selected;
      if (!_borrowingDateEdited) {
        final date = DateTime(selected.year, selected.month, selected.day);
        _borrowingDate = date;
        if (_terms.stages.length == 1 &&
            !first.deferment &&
            first.firstDate == oldDefault) {
          _terms = _terms.replace(
            first.copyWith(
              firstDate: IntervalRepaymentDates.addMonthsClamped(date, 1),
            ),
          );
        }
      }
    });
  }

  Future<void> _pickBorrowingDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _borrowingDate,
      title: '选择合同借款日',
    );
    if (selected == null || !mounted) return;
    final oldDefault = IntervalRepaymentDates.addMonthsClamped(
      _borrowingDate,
      1,
    );
    final first = _terms.stages.first;
    setState(() {
      _borrowingDateEdited = true;
      _borrowingDate = selected;
      if (_terms.stages.length == 1 &&
          !first.deferment &&
          first.firstDate == oldDefault) {
        _terms = _terms.replace(
          first.copyWith(
            firstDate: IntervalRepaymentDates.addMonthsClamped(selected, 1),
          ),
        );
      }
    });
  }

  Future<void> _pickCreditAccount(List<Account> accounts) async {
    final selected = await showAccountPickerSheet(
      context: context,
      accounts: accounts,
      selectedId: _liabilityAccountId,
    );
    if (!mounted || selected == null) return;
    setState(() => _liabilityAccountId = selected);
  }

  Future<void> _pickProduct() async {
    late final List<InstallmentProductReadModel> products;
    try {
      products = await ref.read(installmentProductAppServiceProvider).list();
    } on Exception catch (error) {
      if (mounted) _showError(error.toString());
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<InstallmentProductReadModel>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('选择分期产品')),
            for (final product in products)
              if (!product.archived)
                ListTile(
                  title: Text(product.name),
                  onTap: () => Navigator.of(context).pop(product),
                ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    var terms = InstallmentTermsDraft.product(
      selected.stages,
      selected.dayCount,
      selected.rounding,
    );
    final index = terms.stages.indexWhere((stage) => !stage.deferment);
    if (index >= 0) {
      final stage = terms.stages[index];
      terms = terms.replace(
        stage.copyWith(
          firstDate: IntervalRepaymentDates.addMonthsClamped(_borrowingDate, 1),
        ),
      );
    }
    setState(() {
      _productName = selected.name;
      _terms = terms;
    });
  }

  Future<void> _openCategoryForm({String? parentId}) async {
    final queryParameters = <String, String>{'type': AccountType.expense.name};
    if (parentId != null) queryParameters['parentId'] = parentId;
    final uri = Uri(path: '/category/new', queryParameters: queryParameters);
    await context.push(uri.toString());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.tryParse(_amountController.text.trim());
    if (amount == null || amount.minorUnits <= 0) {
      _showError('请输入有效成交价');
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      _showError('请选择支出分类');
      return;
    }
    final liabilityAccountId = _liabilityAccountId;
    if (liabilityAccountId == null) {
      _showError('请选择信用账户');
      return;
    }
    final downPaymentTotal = sumAllocations(_downPayments);
    if (downPaymentTotal.minorUnits >= amount.minorUnits) {
      _showError('融资本金必须大于零');
      return;
    }
    final financed = amount - downPaymentTotal;
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(installmentContractAppServiceProvider)
          .createConsumptionInstallment(
            CreateConsumptionInstallmentCommand(
              name: _trimmedOrNull(_nameController.text),
              liabilityAccountId: liabilityAccountId,
              amount: amount,
              categoryAllocations: [
                ConsumptionInstallmentAllocation(
                  accountId: categoryId,
                  amount: amount,
                ),
              ],
              settlementAllocations: [
                for (final allocation in _downPayments)
                  ConsumptionInstallmentAllocation(
                    accountId: allocation.accountId,
                    amount: allocation.amount,
                  ),
                ConsumptionInstallmentAllocation(
                  accountId: liabilityAccountId,
                  amount: financed,
                ),
              ],
              borrowingDate: _borrowingDate,
              occurredAt: _occurredAt,
              note: _trimmedOrNull(_noteController.text),
              stageTerms: _terms.contractTerms(),
            ),
          );
      if (!mounted) return;
      context.go('/installments/${result.contractId}');
    } on Exception catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst('AppException: ', '')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String _dateText(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String? _trimmedOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
