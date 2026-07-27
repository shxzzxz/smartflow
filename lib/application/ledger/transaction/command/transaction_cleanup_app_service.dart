import 'package:smartflow/application/shared/transaction_runner.dart';

import '../query/port/transaction_read_repository.dart';
import '../query/transaction_queries.dart';
import 'transaction_command.dart';
import 'transaction_edit_app_service.dart';

abstract interface class TransactionCleanupAppService {
  Future<TransactionCleanupResult> cleanupTransactions(
    CleanupTransactionsCommand command,
  );
}

/// 按条件批量删除交易组。
///
/// 复用单笔删除的整组删除与余额回冲逻辑，整个清理在同一个数据库事务内完成。
/// 带业务归属的交易组不在账务侧删除，计入跳过数量，由所属业务域自行清理。
class TransactionCleanupAppServiceImpl implements TransactionCleanupAppService {
  TransactionCleanupAppServiceImpl({
    required TransactionRunner transactionRunner,
    required TransactionReadRepository transactionReadRepository,
    required TransactionEditAppService editService,
  }) : _transactionRunner = transactionRunner,
       _transactionRead = transactionReadRepository,
       _editService = editService;

  final TransactionRunner _transactionRunner;
  final TransactionReadRepository _transactionRead;
  final TransactionEditAppService _editService;

  @override
  Future<TransactionCleanupResult> cleanupTransactions(
    CleanupTransactionsCommand command,
  ) {
    return _transactionRunner.run(() async {
      final targets = await _transactionRead.findCleanupTargets(
        TransactionCleanupQuery(
          categoryIds: command.categoryIds,
          accountIds: command.accountIds,
          occurredFrom: command.occurredFrom,
          occurredUntil: command.occurredUntil,
        ),
      );
      var deletedGroupCount = 0;
      var skippedGroupCount = 0;
      for (final target in targets) {
        if (target.owned) {
          skippedGroupCount++;
          continue;
        }
        await _editService.deleteTransaction(
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
}
