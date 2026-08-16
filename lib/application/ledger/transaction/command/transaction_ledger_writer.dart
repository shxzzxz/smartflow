import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_deletion_result.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_result.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_update_result.dart';
import 'package:smartflow/domain/ledger/valobj/posting_result.dart';
import 'package:smartflow/application/ledger/tag/query/port/tag_repository.dart';

import 'transaction_command.dart';

class TransactionLedgerWriter {
  const TransactionLedgerWriter({
    required TransactionRunner transactionRunner,
    required TransactionRepository transactionRepository,
    required TransactionGroupRepository transactionGroupRepository,
    required AccountRepository accountRepository,
    required TransactionTagRepository transactionTagRepository,
  }) : _transactionRunner = transactionRunner,
       _transactionRepository = transactionRepository,
       _transactionGroupRepository = transactionGroupRepository,
       _accountRepository = accountRepository,
       _transactionTagRepository = transactionTagRepository;

  final TransactionRunner _transactionRunner;
  final TransactionRepository _transactionRepository;
  final TransactionGroupRepository _transactionGroupRepository;
  final AccountRepository _accountRepository;
  final TransactionTagRepository _transactionTagRepository;

  /// [tagIds] 为 null 表示本次重写不改标签；非 null 集合表示用该集合
  /// 整体替换交易标签（空集合即清空）。
  Future<PostedTransactionResult> planAndPersistRewrite(
    Future<TransactionGroupRewriteResult> Function() plan, {
    Set<String>? tagIds,
  }) {
    return _transactionRunner.run(() async {
      final result = await _persistRewrite(await plan());
      if (tagIds != null) {
        await _transactionTagRepository.replaceTransactionTags(
          transactionId: result.transactionId,
          tagIds: tagIds,
        );
      }
      return result;
    });
  }

  Future<void> planAndPersistDeletion(
    Future<TransactionDeletionResult> Function() plan,
  ) {
    return _transactionRunner.run(() async {
      await _persistDeletion(await plan());
    });
  }

  /// [tagIds] 非空时随新交易一并写入；空集合跳过写入（新交易本无标签可清）。
  Future<PostedTransactionResult> persistPosting(
    PostingResult posting, {
    Set<String> tagIds = const {},
  }) async {
    return _transactionRunner.run(() async {
      await _transactionRepository.save(posting.transaction);
      await _accountRepository.saveAll(posting.accounts);
      if (tagIds.isNotEmpty) {
        await _transactionTagRepository.replaceTransactionTags(
          transactionId: posting.transaction.id,
          tagIds: tagIds,
        );
      }
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
    await _transactionGroupRepository.applyRewrite(rewrite.plan);
    await _accountRepository.saveAll(rewrite.accounts);
    return PostedTransactionResult(
      transactionId: rewrite.currentTransaction.id,
    );
  }

  Future<void> _persistDeletion(TransactionDeletionResult deletion) async {
    if (deletion.deletesGroup) {
      await _transactionGroupRepository.deleteGroup(
        deletion.targetTransactionId,
      );
    } else {
      await _transactionGroupRepository.deleteChild(
        deletion.targetTransactionId,
      );
    }
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
