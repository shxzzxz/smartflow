import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';
import '../../port/root_transaction_group_repository.dart';
import '../../port/transaction_repository.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';

class LedgerUpdateService {
  const LedgerUpdateService({
    required TransactionRepository transactionRepository,
    required RootTransactionGroupRepository rootGroupRepository,
  }) : _transactionRepository = transactionRepository,
       _rootGroupRepository = rootGroupRepository;

  final TransactionRepository _transactionRepository;
  final RootTransactionGroupRepository _rootGroupRepository;

  Future<Result<TransactionUpdateResult>> updateBasicInfo(
    UpdateTransactionBasicInfoInstruction instruction,
  ) async {
    if (instruction.occurredAt == null &&
        instruction.counterpartyName == null &&
        instruction.note == null) {
      return _empty(instruction.transactionId);
    }

    final transaction = await _transactionRepository.findCompleteById(
      instruction.transactionId,
    );
    if (transaction == null) return _failure('transaction_not_found');
    final updateFailure = transaction.assertCanBeBasicsUpdated();
    if (updateFailure != null) return Result.failure(updateFailure);

    transaction.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
    return Result.success(
      TransactionUpdateResult(
        transactions: [transaction],
        accounts: const [],
        currentTransaction: transaction,
      ),
    );
  }

  Future<Result<TransactionUpdateResult>> updateReportingFlag(
    UpdateTransactionReportingFlagInstruction instruction,
  ) async {
    if (instruction.isExcludedFromStats == null &&
        instruction.isExcludedFromBudget == null) {
      return _empty(instruction.transactionId);
    }

    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) return _failure('transaction_not_found');
    group.updateReportingFlags(
      isExcludedFromStats: instruction.isExcludedFromStats,
      isExcludedFromBudget: instruction.isExcludedFromBudget,
    );
    final current = group.findTransaction(instruction.transactionId);
    if (current == null) return _failure('transaction_not_found');
    return Result.success(
      TransactionUpdateResult(
        transactions: group.transactions.toList(),
        accounts: const [],
        currentTransaction: current,
      ),
    );
  }

  Future<Result<TransactionUpdateResult>> updateOwnership(
    UpdateTransactionOwnershipInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) return _failure('transaction_not_found');
    group.updateOwnership(instruction.ownership);
    final current = group.findTransaction(instruction.transactionId);
    if (current == null) return _failure('transaction_not_found');
    return Result.success(
      TransactionUpdateResult(
        transactions: group.transactions.toList(),
        accounts: const [],
        currentTransaction: current,
      ),
    );
  }

  Future<Result<TransactionUpdateResult>> _empty(String transactionId) async {
    final transaction = await _transactionRepository.findCompleteById(
      transactionId,
    );
    if (transaction == null) return _failure('transaction_not_found');
    return Result.success(
      TransactionUpdateResult(
        transactions: const [],
        accounts: const [],
        currentTransaction: transaction,
      ),
    );
  }

  Result<T> _failure<T>(String code) {
    return Result.failure(
      Failure(code: code, message: 'Ledger update failed: $code.'),
    );
  }
}
