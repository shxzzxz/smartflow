import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../query/port/transaction_read_repository.dart';
import '../../tag/query/port/tag_repository.dart';
import '../query/transaction_queries.dart';
import 'transaction_batch_command.dart';
import 'transaction_command.dart';
import 'transaction_edit_app_service.dart';

abstract interface class TransactionBatchOperationAppService {
  Future<TransactionCleanupResult> deleteTransactions(
    BatchDeleteTransactionsCommand command,
  );

  Future<TransactionBatchTagResult> updateTags(
    BatchTransactionTagsCommand command,
  );
}

class TransactionBatchOperationAppServiceImpl
    implements TransactionBatchOperationAppService {
  TransactionBatchOperationAppServiceImpl({
    required TransactionRunner transactionRunner,
    required TransactionReadRepository transactionReadRepository,
    required TransactionEditAppService transactionEditService,
    required TransactionTagRepository transactionTagRepository,
  }) : _transactionRunner = transactionRunner,
       _transactionReadRepository = transactionReadRepository,
       _transactionEditService = transactionEditService,
       _transactionTagRepository = transactionTagRepository;

  final TransactionRunner _transactionRunner;
  final TransactionReadRepository _transactionReadRepository;
  final TransactionEditAppService _transactionEditService;
  final TransactionTagRepository _transactionTagRepository;

  @override
  Future<TransactionCleanupResult> deleteTransactions(
    BatchDeleteTransactionsCommand command,
  ) async {
    if (command.transactionIds.isEmpty) {
      return const TransactionCleanupResult(
        deletedGroupCount: 0,
        skippedGroupCount: 0,
      );
    }
    return _transactionRunner.run(() async {
      final targets = await _transactionReadRepository.findCleanupTargets(
        TransactionCleanupQuery(transactionIds: command.transactionIds),
      );
      var deletedGroupCount = 0;
      var skippedGroupCount = 0;
      for (final target in targets) {
        if (target.owned) {
          skippedGroupCount++;
          continue;
        }
        await _transactionEditService.deleteTransaction(
          DeleteTransactionCommand(transactionId: target.transactionId),
        );
        deletedGroupCount++;
      }
      return TransactionCleanupResult(
        deletedGroupCount: deletedGroupCount,
        skippedGroupCount: skippedGroupCount,
      );
    });
  }

  @override
  Future<TransactionBatchTagResult> updateTags(
    BatchTransactionTagsCommand command,
  ) async {
    if (command.transactionIds.isEmpty) {
      return const TransactionBatchTagResult(
        updatedGroupCount: 0,
        skippedGroupCount: 0,
      );
    }
    return _transactionRunner.run(() async {
      final transactions = await _transactionReadRepository.findByIds(
        command.transactionIds,
      );
      var updatedGroupCount = 0;
      for (final transaction in transactions) {
        if (!_canEditTags(transaction.businessPurpose) ||
            transaction.ownership != null) {
          continue;
        }
        final currentTagIds = await _transactionTagRepository.transactionTagIds(
          transaction.id,
        );
        final nextTagIds = switch (command.operation) {
          TransactionTagBatchOperation.add => {
            ...currentTagIds,
            ...command.tagIds,
          },
          TransactionTagBatchOperation.remove => currentTagIds.difference(
            command.tagIds,
          ),
          TransactionTagBatchOperation.clear => <String>{},
        };
        await _transactionTagRepository.replaceTransactionTags(
          transactionId: transaction.id,
          tagIds: nextTagIds,
        );
        updatedGroupCount++;
      }
      return TransactionBatchTagResult(
        updatedGroupCount: updatedGroupCount,
        skippedGroupCount: command.transactionIds.length - updatedGroupCount,
      );
    });
  }

  bool _canEditTags(BusinessPurpose purpose) {
    return switch (purpose) {
      BusinessPurpose.dailyExpense ||
      BusinessPurpose.dailyIncome ||
      BusinessPurpose.transfer ||
      BusinessPurpose.reimbursementAdvance ||
      BusinessPurpose.borrowing ||
      BusinessPurpose.lending ||
      BusinessPurpose.receivableCollection ||
      BusinessPurpose.badDebt ||
      BusinessPurpose.debtRelief ||
      BusinessPurpose.debtRepayment => true,
      BusinessPurpose.refund ||
      BusinessPurpose.reimbursementReceipt ||
      BusinessPurpose.reimbursementClose ||
      BusinessPurpose.openingBalance ||
      BusinessPurpose.balanceAdjustment => false,
    };
  }
}
