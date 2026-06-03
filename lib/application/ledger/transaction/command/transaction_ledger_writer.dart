import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/ledger/valobj/posting_result.dart';

import 'transaction_command.dart';

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

  Future<PostedTransactionResult> persistPostingValue(
    PostingResult posting,
  ) async {
    return _transactionRunner.runValue(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      return PostedTransactionResult(
        transactionId: posting.transaction.id,
        rootTransactionId: posting.transaction.rootTransactionId,
      );
    });
  }

  Future<PostedTransactionResult> persistPostingResultValue(
    Result<PostingResult> postingResult,
  ) {
    return persistPostingValue(_valueOrThrow(postingResult));
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

  Future<PostedTransactionResult> persistMutationValue(
    Result<MutationResult> mutationResult,
  ) async {
    final mutation = _valueOrThrow(mutationResult);
    return _transactionRunner.runValue(() async {
      await _transactionRepository.saveAll(mutation.transactions);
      await _accountRepository.saveAll(mutation.accounts);
      return PostedTransactionResult(
        transactionId: mutation.currentTransaction.id,
        rootTransactionId: mutation.currentTransaction.rootTransactionId,
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

  Future<void> persistCancellationValue(
    Result<CancellationResult> cancellationResult,
  ) async {
    final cancellation = _valueOrThrow(cancellationResult);
    return _transactionRunner.runValue(() async {
      await _transactionRepository.saveAll(cancellation.transactions);
      await _accountRepository.saveAll(cancellation.accounts);
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

  T _valueOrThrow<T>(Result<T> result) {
    return switch (result) {
      Success<T>(:final value) => value,
      FailureResult<T>(:final failure) =>
        throw _businessExceptionFromFailure(failure),
    };
  }

  BusinessException _businessExceptionFromFailure(Failure failure) {
    return BusinessException(
      _ledgerErrorCodeFromFailureCode(failure.code),
      message: failure.message,
      cause: failure.cause,
    );
  }

  LedgerErrorCode _ledgerErrorCodeFromFailureCode(String? code) {
    return switch (code) {
      'account_not_found' => LedgerErrorCode.accountNotFound,
      'account_archived' => LedgerErrorCode.accountUnavailable,
      'account_role_invalid' => LedgerErrorCode.accountInvalidRole,
      'account_subtype_invalid' => LedgerErrorCode.accountInvalidRole,
      'transaction_not_found' => LedgerErrorCode.transactionNotFound,
      'parent_transaction_required' => LedgerErrorCode.transactionNotEditable,
      'transaction_not_current' => LedgerErrorCode.transactionNotEditable,
      'transaction_purpose_mismatch' => LedgerErrorCode.transactionNotEditable,
      'reimbursement_parent_not_advance' =>
        LedgerErrorCode.transactionNotEditable,
      'reimbursement_advance_not_current' =>
        LedgerErrorCode.transactionNotEditable,
      'expense_amount_not_positive' =>
        LedgerErrorCode.transactionInvalidCommand,
      _ => LedgerErrorCode.transactionPostingFailed,
    };
  }
}
