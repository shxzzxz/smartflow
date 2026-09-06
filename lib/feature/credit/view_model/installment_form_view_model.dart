import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/credit_account_query_providers.dart';
import '../provider/installment_query_providers.dart';
import 'installment_terms_draft.dart';

part 'installment_form_view_model.g.dart';

final _logger = Logger('feature.credit.installment_form');

@riverpod
class InstallmentFormViewModel extends _$InstallmentFormViewModel {
  @override
  Future<InstallmentFormState> build(InstallmentFormArgs args) async {
    final liabilityAccounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentTarget,
      ).future,
    );
    final fundAccounts = await ref.watch(
      accountsForSelectionPurposeProvider(AccountSelectionPurpose.fund).future,
    );
    final liability = _findAccount(liabilityAccounts, args.liabilityAccountId);
    if (liability == null) return const InstallmentFormNotFound();
    final now = DateTime.now();
    return InstallmentFormLoaded(
      liability: liability,
      fundAccounts: fundAccounts,
      borrowingDate: now,
      termsDraft: InstallmentTermsDraft.loan(now),
    );
  }

  Future<UiActionOutcome<List<InstallmentProductReadModel>>> loadProducts() =>
      guardUiAction(
        _logger,
        'Load installment products',
        () async => ref.read(installmentProductServiceProvider).list(),
      );

  void selectProduct(InstallmentProductReadModel product) => _updateLoaded(
    (s) => s.copyWith(
      termsDraft: InstallmentTermsDraft.product(
        product.stages,
        product.dayCount,
        product.rounding,
      ),
      productId: product.id,
      productName: product.name,
      customRules: false,
    ),
  );
  void setCustomRules(bool value) =>
      _updateLoaded((s) => s.copyWith(customRules: value));
  void setTermsDraft(InstallmentTermsDraft value) =>
      _updateLoaded((s) => s.copyWith(termsDraft: value));
  void setBorrowingDate(DateTime value) => _updateLoaded((s) {
    final stages = s.termsDraft.stages;
    final defaultFirst = IntervalRepaymentDates.addMonthsClamped(
      s.borrowingDate,
      1,
    );
    final first = stages.first;
    final next =
        stages.length == 1 &&
            !first.deferment &&
            first.firstDate == defaultFirst
        ? s.termsDraft.replace(
            first.copyWith(
              firstDate: IntervalRepaymentDates.addMonthsClamped(value, 1),
            ),
          )
        : s.termsDraft;
    return s.copyWith(borrowingDate: value, termsDraft: next);
  });
  void setDisbursementAccountId(String? value) =>
      _updateLoaded((s) => s.copyWith(disbursementAccountId: value));
  void setCreateDisbursementTransaction(bool value) =>
      _updateLoaded((s) => s.copyWith(createDisbursementTransaction: value));

  Future<UiActionOutcome<LoanCalculation>> preview(String principalText) =>
      guardUiAction(_logger, 'Preview loan stages', () async {
        final current = state.requireValue as InstallmentFormLoaded;
        if (current.usesBillingCycle) {
          throw BusinessException(
            CreditErrorCode.contractInvalidCommand,
            message: '信用账户按账期生成计划，创建后可查看',
          );
        }
        final principal = _parsePositiveMoney(principalText);
        if (principal == null) {
          throw BusinessException(
            CreditErrorCode.contractInvalidCommand,
            message: '请输入有效本金',
          );
        }
        return ref
            .read(loanCalculatorQueryProvider)
            .calculate(
              current.termsDraft.contractTerms().planTerms(
                principal,
                current.borrowingDate,
              ),
            );
      });

  Future<UiActionOutcome<String>> submit({
    required String principalText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current is! InstallmentFormLoaded) return _invalidAction('分期表单尚未加载');
    final principal = _parsePositiveMoney(principalText);
    if (principal == null) return _invalidAction('请输入有效本金');
    if (current.createDisbursementTransaction &&
        current.disbursementAccountId == null) {
      return _invalidAction('请选择放款入账账户');
    }
    state = AsyncData(current.copyWith(submitting: true));
    try {
      return await guardUiAction(
        _logger,
        'Create staged installment',
        () async {
          final result = await ref
              .read(installmentAppServiceProvider)
              .createDisbursementContract(
                CreateDisbursementContractCommand(
                  liabilityAccountId: current.liability.id,
                  disbursementAccountId: current.createDisbursementTransaction
                      ? current.disbursementAccountId
                      : null,
                  principal: principal,
                  borrowingDate: current.borrowingDate,
                  productId: current.productId,
                  customRules: current.customRules,
                  note: trimToNull(noteText),
                  stageTerms: current.termsDraft.contractTerms(),
                ),
              );
          ref.invalidate(
            installmentContractsByAccountProvider(current.liability.id),
          );
          ref.invalidate(creditAccountOverviewProvider(current.liability.id));
          return result.contractId;
        },
      );
    } finally {
      _updateLoaded((s) => s.copyWith(submitting: false));
    }
  }

  void _updateLoaded(
    InstallmentFormLoaded Function(InstallmentFormLoaded) update,
  ) {
    final current = state.asData?.value;
    if (current is InstallmentFormLoaded) state = AsyncData(update(current));
  }

  UiActionOutcome<String> _invalidAction(String message) =>
      UiActionOutcome.failure(
        UiError(
          code: CreditErrorCode.contractInvalidCommand.code,
          message: message,
        ),
      );
}

class InstallmentFormArgs {
  const InstallmentFormArgs({
    required this.liabilityAccountId,
    this.lockedSourceType,
  });

  final String liabilityAccountId;
  final InstallmentSourceType? lockedSourceType;

  @override
  bool operator ==(Object other) {
    return other is InstallmentFormArgs &&
        other.liabilityAccountId == liabilityAccountId &&
        other.lockedSourceType == lockedSourceType;
  }

  @override
  int get hashCode => Object.hash(liabilityAccountId, lockedSourceType);
}

sealed class InstallmentFormState {
  const InstallmentFormState();
}

class InstallmentFormNotFound extends InstallmentFormState {
  const InstallmentFormNotFound();
}

class InstallmentFormLoaded extends InstallmentFormState {
  const InstallmentFormLoaded({
    required this.liability,
    required this.fundAccounts,
    required this.borrowingDate,
    required this.termsDraft,
    this.disbursementAccountId,
    this.productId,
    this.productName,
    this.customRules = true,
    this.createDisbursementTransaction = true,
    this.submitting = false,
  });
  final Account liability;
  final List<Account> fundAccounts;
  final DateTime borrowingDate;
  final InstallmentTermsDraft termsDraft;
  final String? disbursementAccountId, productId, productName;
  final bool customRules, createDisbursementTransaction, submitting;
  bool get isDisbursement => true;
  bool get usesBillingCycle =>
      liability.profileKey == AccountProfileKind.credit.key;
  bool get canChooseProduct =>
      liability.profileKey == AccountProfileKind.loan.key;
  InstallmentFormLoaded copyWith({
    DateTime? borrowingDate,
    InstallmentTermsDraft? termsDraft,
    Object? disbursementAccountId = _sentinel,
    String? productId,
    String? productName,
    bool? customRules,
    bool? createDisbursementTransaction,
    bool? submitting,
  }) => InstallmentFormLoaded(
    liability: liability,
    fundAccounts: fundAccounts,
    borrowingDate: borrowingDate ?? this.borrowingDate,
    termsDraft: termsDraft ?? this.termsDraft,
    disbursementAccountId: disbursementAccountId == _sentinel
        ? this.disbursementAccountId
        : disbursementAccountId as String?,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    customRules: customRules ?? this.customRules,
    createDisbursementTransaction:
        createDisbursementTransaction ?? this.createDisbursementTransaction,
    submitting: submitting ?? this.submitting,
  );
}

const _sentinel = Object();

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits > 0 ? money : null;
}
