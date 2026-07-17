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

  Future<PostedTransactionResult> planAndPersistRewrite(
    Future<TransactionGroupRewriteResult> Function() plan,
  ) {
    return _transactionRunner.run(() async {
      return _persistRewrite(await plan());
    });
  }

  Future<void> planAndPersistDeletion(
    Future<TransactionDeletionResult> Function() plan,
  ) {
    return _transactionRunner.run(() async {
      await _persistDeletion(await plan());
    });
  }

  Future<PostedTransactionResult> persistPosting(PostingResult posting) async {
    return _transactionRunner.run(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      return PostedTransactionResult(transactionId: posting.transaction.id);
    });
  }

  Future<PostedTransactionResult> persistRewrite(
    TransactionGroupRewriteResult rewrite,
  ) async {
    return _transactionRunner.run(() => _persistRewrite(rewrite));
  }

  Future<void> persistDeletion(TransactionDeletionResult deletion) async {
    return _transactionRunner.run(() => _persistDeletion(deletion));
  }

  Future<PostedTransactionResult> _persistRewrite(
    TransactionGroupRewriteResult rewrite,
  ) async {
    await _transactionRepository.rewriteAll(
      rewrite.plan.rewrites.map((item) => item.after),
    );
    await _accountRepository.saveAll(rewrite.accounts);
    return PostedTransactionResult(
      transactionId: rewrite.currentTransaction.id,
    );
  }

  Future<void> _persistDeletion(TransactionDeletionResult deletion) async {
    await _transactionRepository.deleteAll({
      for (final transaction in deletion.deletedTransactions) transaction.id,
    });
    await _accountRepository.saveAll(deletion.accounts);
  }

  Future<PostedTransactionResult> persistUpdate(
    TransactionUpdateResult update,
  ) async {
    return _transactionRunner.run(() async {
      await _transactionRepository.saveAll(update.transactions);
      await _accountRepository.saveAll(update.accounts);
      return PostedTransactionResult(
        transactionId: update.currentTransaction.id,
      );
    });
  }
}
