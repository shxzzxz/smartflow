import '../../application/ledger/transaction/command/transaction_command.dart';
import '../../application/ledger/transaction/command/transaction_edit_app_service.dart';
import '../../application/ledger/transaction/command/transaction_posting_app_service.dart';
import '../../application/ledger/transaction/command/transaction_update_app_service.dart';
import '../../core/error/app_exception.dart';
import '../../core/money/money.dart';
import '../../domain/ledger/port/account_repository.dart';
import '../../domain/ledger/port/transaction_repository.dart';
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
    required TransactionUpdateAppService updating,
    required AccountRepository accounts,
    required TransactionRepository transactions,
  }) : _posting = posting,
       _editing = editing,
       _updating = updating,
       _accounts = accounts,
       _transactions = transactions;

  final TransactionPostingAppService _posting;
  final TransactionEditAppService _editing;
  final TransactionUpdateAppService _updating;
  final AccountRepository _accounts;
  final TransactionRepository _transactions;

  @override
  Future<void> validatePlanAccounts({
    required AmortizationKind kind,
    required String deferralAccountId,
    required String categoryAccountId,
  }) async {
    final accounts = await _accounts.findByIds({
      deferralAccountId,
      categoryAccountId,
    });
    final byId = {for (final account in accounts) account.id: account};
    final deferral = byId[deferralAccountId];
    final category = byId[categoryAccountId];
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
    if (category == null ||
        category.archivedAt != null ||
        category.type != expectedCategoryType) {
      throw BusinessException(
        AmortizationErrorCode.invalidCommand,
        message: 'Recognition category does not match the amortization kind.',
      );
    }
  }

  @override
  Future<String> postTransfer({
    required Money amount,
    required String fromAccountId,
    required String toAccountId,
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
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
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
  Future<void> deleteTransaction(String transactionId) async {
    await _editing.deleteTransaction(
      DeleteTransactionCommand(transactionId: transactionId),
    );
  }

  @override
  Future<void> updateReportingFlags({
    required String transactionId,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
  }) async {
    await _updating.updateReportingFlag(
      UpdateTransactionReportingFlagCommand(
        transactionId: transactionId,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
      ),
    );
  }

  @override
  Future<bool> isOwnedBy({
    required String transactionId,
    required TransactionOwnership ownership,
  }) async {
    final transaction = await _transactions.findById(transactionId);
    return transaction?.ownership == ownership;
  }
}
