import '../../../core/result/result.dart';
import '../../../application/shared/transaction_runner.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import '../command/transaction_command.dart';
import 'package:smartflow/domain/ledger/valobj/posting_result.dart';

class TransactionLedgerWriter {
  const TransactionLedgerWriter({
    required TransactionRunner transactionRunner,
    required TransactionRepository transactionRepository,
    required AccountRepository accountRepository,
  }) : _transactionRunner = transactionRunner,
       _transactionRepository = transactionRepository,
       _accountRepository = accountRepository;

  final TransactionRunner _transactionRunner;
  final TransactionRepository _transactionRepository;
  final AccountRepository _accountRepository;

  Future<Result<PostedTransactionResult>> persistPosting(
    Result<PostingResult> postingResult,
  ) async {
    if (postingResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final posting = postingResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      return Result.success(
        PostedTransactionResult(
          transactionId: posting.transaction.id,
          rootTransactionId: posting.transaction.rootTransactionId,
        ),
      );
    });
  }

  Future<Result<PostedTransactionResult>> persistMutation(
    Result<MutationResult> mutationResult,
  ) async {
    if (mutationResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final mutation = mutationResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(mutation.transactions);
      await _accountRepository.saveAll(mutation.accounts);
      return Result.success(
        PostedTransactionResult(
          transactionId: mutation.currentTransaction.id,
          rootTransactionId: mutation.currentTransaction.rootTransactionId,
        ),
      );
    });
  }

  Future<Result<void>> persistCancellation(
    Result<CancellationResult> cancellationResult,
  ) async {
    if (cancellationResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final cancellation = cancellationResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(cancellation.transactions);
      await _accountRepository.saveAll(cancellation.accounts);
      return const Result.success(null);
    });
  }

  Future<Result<PostedTransactionResult>> persistUpdate(
    Result<TransactionUpdateResult> updateResult,
  ) async {
    if (updateResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final update = updateResult.value;
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(update.transactions);
      await _accountRepository.saveAll(update.accounts);
      return Result.success(
        PostedTransactionResult(
          transactionId: update.currentTransaction.id,
          rootTransactionId: update.currentTransaction.rootTransactionId,
        ),
      );
    });
  }
}
