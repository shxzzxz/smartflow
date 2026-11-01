import '../../application/ledger/transaction/command/transaction_command.dart';
import '../../application/ledger/transaction/command/transaction_edit_app_service.dart';
import '../../application/ledger/transaction/command/transaction_posting_app_service.dart';
import '../../core/error/app_exception.dart';
import '../../core/money/money.dart';
import '../../domain/ledger/port/account_repository.dart';
import '../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../domain/ledger/valobj/ledger_enum.dart';
import '../../domain/ledger/valobj/transaction_ownership.dart';
import '../../domain/orchestration/port/amortization_ledger_port.dart';
import '../../domain/orchestration/valobj/amortization_enums.dart';
import '../../domain/orchestration/valobj/amortization_error_code.dart';

class LedgerAmortizationPort implements AmortizationLedgerPort {
  const LedgerAmortizationPort({
    required TransactionPostingAppService posting,
    required TransactionEditAppService editing,
    required AccountRepository accounts,
  }) : _posting = posting,
       _editing = editing,
       _accounts = accounts;

  final TransactionPostingAppService _posting;
  final TransactionEditAppService _editing;
  final AccountRepository _accounts;

  @override
  Future<void> validatePlanAccounts({
    required AmortizationKind kind,
    required String deferralAccountId,
    required Iterable<String> categoryAccountIds,
  }) async {
    final categoryIds = categoryAccountIds.toSet();
    final accounts = await _accounts.findByIds({
      deferralAccountId,
      ...categoryIds,
    });
    final byId = {for (final account in accounts) account.id: account};
    final deferral = byId[deferralAccountId];
    final expectedSubtype = switch (kind) {
      AmortizationKind.prepaidExpense => AccountSubtype.prepaidExpense,
      AmortizationKind.deferredIncome => AccountSubtype.deferredIncome,
    };
    final expectedCategoryType = switch (kind) {
      AmortizationKind.prepaidExpense => AccountType.expense,
      AmortizationKind.deferredIncome => AccountType.income,
    };
    if (deferral == null ||
        deferral.archivedAt != null ||
        deferral.subtype != expectedSubtype) {
      throw BusinessException(
        AmortizationErrorCode.invalidCommand,
        message: 'Deferral account does not match the amortization kind.',
      );
    }
    for (final categoryAccountId in categoryIds) {
      final category = byId[categoryAccountId];
      if (category == null ||
          category.archivedAt != null ||
          category.type != expectedCategoryType) {
        throw BusinessException(
          AmortizationErrorCode.invalidCommand,
          message: 'Recognition category does not match the amortization kind.',
        );
      }
    }
  }

  @override
  Future<void> validateRefundAccounts({
    required AmortizationKind kind,
    required Iterable<String> categoryAccountIds,
    required Iterable<String> settlementAccountIds,
  }) async {
    final categoryIds = categoryAccountIds.toSet();
    final settlementIds = settlementAccountIds.toSet();
    final accounts = await _accounts.findByIds({
      ...categoryIds,
      ...settlementIds,
    });
    final byId = {for (final account in accounts) account.id: account};
    final expectedCategoryType = switch (kind) {
      AmortizationKind.prepaidExpense => AccountType.expense,
      AmortizationKind.deferredIncome => AccountType.income,
    };
    for (final categoryAccountId in categoryIds) {
      final category = byId[categoryAccountId];
      if (category == null ||
          category.archivedAt != null ||
          category.type != expectedCategoryType) {
        throw BusinessException(
          AmortizationErrorCode.invalidCommand,
          message: 'Refund category does not match the amortization kind.',
        );
      }
    }
    for (final settlementAccountId in settlementIds) {
      final account = byId[settlementAccountId];
      if (account == null ||
          account.archivedAt != null ||
          !account.type.isUserAccount) {
        throw BusinessException(
          AmortizationErrorCode.invalidCommand,
          message: 'Refund settlement account is unavailable.',
        );
      }
    }
  }

  @override
  Future<String> postTransfer({
    required Money amount,
    required List<AccountAmountAllocation> outgoingAllocations,
    required List<AccountAmountAllocation> incomingAllocations,
    required DateTime occurredAt,
    DateTime? postedAt,
    Money? feeAmount,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  }) async {
    final result = await _posting.createTransfer(
      CreateTransferCommand(
        amount: amount,
        outgoingAllocations: outgoingAllocations,
        incomingAllocations: incomingAllocations,
        occurredAt: occurredAt,
        postedAt: postedAt,
        feeAmount: feeAmount,
        counterpartyId: counterpartyId,
        note: note,
        ownership: ownership,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        sourceKind: sourceKind,
        tagIds: tagIds,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> postExpense({
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.auto,
    Set<String> tagIds = const {},
  }) async {
    final result = await _posting.createExpense(
      CreateExpenseCommand(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlementAllocations,
        occurredAt: occurredAt,
        counterpartyId: counterpartyId,
        note: note,
        ownership: ownership,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        sourceKind: sourceKind,
        tagIds: tagIds,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> postIncome({
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.auto,
    Set<String> tagIds = const {},
  }) async {
    final result = await _posting.createIncome(
      CreateIncomeCommand(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlementAllocations,
        occurredAt: occurredAt,
        counterpartyId: counterpartyId,
        note: note,
        ownership: ownership,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        sourceKind: sourceKind,
        tagIds: tagIds,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<void> rewriteExpense({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  }) async {
    await _editing.editExpense(
      EditExpenseCommand(
        transactionId: transactionId,
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlementAllocations,
      ),
    );
  }

  @override
  Future<void> rewriteIncome({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  }) async {
    await _editing.editIncome(
      EditIncomeCommand(
        transactionId: transactionId,
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlementAllocations,
      ),
    );
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    await _editing.deleteTransaction(
      DeleteTransactionCommand(transactionId: transactionId),
    );
  }
}
