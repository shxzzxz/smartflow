import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
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

  Future<PostedTransactionResult> persistPosting(PostingResult posting) async {
    return _transactionRunner.run(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      return PostedTransactionResult(
        transactionId: posting.transaction.id,
        rootTransactionId: posting.transaction.rootTransactionId,
      );
    });
  }

  Future<PostedTransactionResult> persistMutation(
    MutationResult mutation,
  ) async {
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(mutation.transactions);
      await _accountRepository.saveAll(mutation.accounts);
      return PostedTransactionResult(
        transactionId: mutation.currentTransaction.id,
        rootTransactionId: mutation.currentTransaction.rootTransactionId,
      );
    });
  }

  Future<void> persistCancellation(CancellationResult cancellation) async {
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(cancellation.transactions);
      await _accountRepository.saveAll(cancellation.accounts);
    });
  }

  Future<PostedTransactionResult> persistUpdate(
    TransactionUpdateResult update,
  ) async {
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(update.transactions);
      await _accountRepository.saveAll(update.accounts);
      return PostedTransactionResult(
        transactionId: update.currentTransaction.id,
        rootTransactionId: update.currentTransaction.rootTransactionId,
      );
    });
  }
}
