/// 批量标签操作的种类。
enum TransactionTagBatchOperation { add, remove, clear }

class BatchTransactionTagsCommand {
  BatchTransactionTagsCommand({
    required Set<String> transactionIds,
    required this.operation,
    Set<String> tagIds = const {},
  }) : transactionIds = Set.unmodifiable(transactionIds),
       tagIds = Set.unmodifiable(tagIds);

  final Set<String> transactionIds;
  final TransactionTagBatchOperation operation;
  final Set<String> tagIds;
}

class BatchDeleteTransactionsCommand {
  BatchDeleteTransactionsCommand({required Set<String> transactionIds})
    : transactionIds = Set.unmodifiable(transactionIds);

  final Set<String> transactionIds;
}

class TransactionBatchTagResult {
  const TransactionBatchTagResult({
    required this.updatedGroupCount,
    required this.skippedGroupCount,
  });

  final int updatedGroupCount;
  final int skippedGroupCount;
}
