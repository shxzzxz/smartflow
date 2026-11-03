import '../../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../ledger/transaction/query/transaction_read_models.dart';
import '../transaction_detail_context_read_models.dart';

/// Owner-specific read seam consumed by the transaction detail context.
abstract interface class TransactionDetailOwnerQuery {
  Set<String> get supportedOwnerTypes;

  Future<TransactionDetailOwnerContext?> find(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  );

  Stream<TransactionDetailOwnerContext?> watch(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  );
}
