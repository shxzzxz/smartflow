import '../../port/transaction_group_repository.dart';
import '../../port/transaction_repository.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import 'transaction_update_result.dart';

class LedgerUpdateService {
  const LedgerUpdateService({
    required TransactionRepository transactionRepository,
    required TransactionGroupRepository transactionGroupRepository,
  }) : _transactionRepository = transactionRepository,
       _transactionGroupRepository = transactionGroupRepository;

  final TransactionRepository _transactionRepository;
  final TransactionGroupRepository _transactionGroupRepository;

  Future<TransactionUpdateResult> updateBasicInfo(
    UpdateTransactionBasicInfoInstruction instruction,
  ) async {
    if (instruction.occurredAt == null &&
        instruction.postedAt == null &&
        instruction.counterpartyId == null &&
        instruction.note == null) {
      return _empty(instruction.transactionId);
    }

    final transaction = await _transactionRepository.findCompleteById(
      instruction.transactionId,
    );
    if (transaction == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    transaction.assertCanBeBasicsUpdated();

    transaction.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      postedAt: instruction.postedAt,
      counterpartyId: instruction.counterpartyId,
      note: instruction.note,
    );
    return TransactionUpdateResult(
      transactions: [transaction],
      accounts: const [],
      currentTransaction: transaction,
    );
  }

  Future<TransactionUpdateResult> updateReportingFlag(
    UpdateTransactionReportingFlagInstruction instruction,
  ) async {
    if (instruction.isExcludedFromStats == null &&
        instruction.isExcludedFromBudget == null) {
      return _empty(instruction.transactionId);
    }

    final group = await _transactionGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    if (instruction.transactionId != group.parentTransaction.id) {
      LedgerViolationReason.parentTransactionRequired.throwException(
        message: '子交易跟随所属交易组设置，请在顶层交易修改统计与预算配置。',
      );
    }
    group.updateReportingFlags(
      isExcludedFromStats: instruction.isExcludedFromStats,
      isExcludedFromBudget: instruction.isExcludedFromBudget,
    );
    final current = group.findTransaction(instruction.transactionId);
    if (current == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    return TransactionUpdateResult(
      transactions: group.transactions.toList(),
      accounts: const [],
      currentTransaction: current,
    );
  }

  Future<TransactionUpdateResult> updateOwnership(
    UpdateTransactionOwnershipInstruction instruction,
  ) async {
    final transaction = await _transactionRepository.findCompleteById(
      instruction.transactionId,
    );
    if (transaction == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    transaction.updateOwnership(instruction.ownership);
    return TransactionUpdateResult(
      transactions: [transaction],
      accounts: const [],
      currentTransaction: transaction,
    );
  }

  Future<TransactionUpdateResult> _empty(String transactionId) async {
    final transaction = await _transactionRepository.findCompleteById(
      transactionId,
    );
    if (transaction == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    return TransactionUpdateResult(
      transactions: const [],
      accounts: const [],
      currentTransaction: transaction,
    );
  }
}
