import '../../../core/errors/failure.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../domain/accounting/accounting_api.dart';
import 'transaction_action_policy.dart';

/// 普通交易的默认 policy：所有 universal 动作直接走 [TransactionService]。
class DefaultTransactionActionPolicy implements TransactionActionPolicy {
  const DefaultTransactionActionPolicy({
    required TransactionService service,
    required int transactionId,
    required BusinessPurpose businessPurpose,
  }) : _service = service,
       _transactionId = transactionId,
       _businessPurpose = businessPurpose;

  final TransactionService _service;
  final int _transactionId;
  final BusinessPurpose _businessPurpose;

  @override
  Future<Result<void>> delete() {
    return _service.deleteTransaction(
      DeleteTransactionCommand(transactionId: _transactionId),
    );
  }

  @override
  String editRoutePath() {
    return switch (_businessPurpose) {
      BusinessPurpose.debtRepayment =>
        '/transactions/$_transactionId/repayment/edit',
      _ => '/transactions/$_transactionId/edit',
    };
  }

  @override
  Future<Result<void>> changeSettlementAccount(int newAccountId) {
    return _service.updateTransactionBasics(
      UpdateTransactionBasicsCommand(
        transactionId: _transactionId,
        settlementAccountId: newAccountId,
      ),
    );
  }

  @override
  Future<Result<void>> changeOccurredAt(DateTime newTime) {
    return _service.updateTransactionBasics(
      UpdateTransactionBasicsCommand(
        transactionId: _transactionId,
        occurredAt: newTime,
      ),
    );
  }

  @override
  Future<Result<void>> changeNote(String? newNote) {
    return _service.updateTransactionMetadata(
      UpdateTransactionMetadataCommand(
        transactionId: _transactionId,
        note: newNote == null
            ? const Patch<String>.clear()
            : Patch.set(newNote),
      ),
    );
  }

  @override
  EditPermission canEdit(EditableField field) => const EditPermission.allowed();

  @override
  String? displayBanner() => null;
}

class UnknownOwnedTransactionActionPolicy implements TransactionActionPolicy {
  const UnknownOwnedTransactionActionPolicy({
    required TransactionService service,
    required int transactionId,
    required String ownerType,
  }) : _service = service,
       _transactionId = transactionId,
       _ownerType = ownerType;

  final TransactionService _service;
  final int _transactionId;
  final String _ownerType;

  @override
  Future<Result<void>> delete() async => const Result.failure(
    Failure(
      code: 'transaction_owner_unknown',
      message: 'This transaction belongs to an unknown business owner.',
    ),
  );

  @override
  String editRoutePath() => '';

  @override
  Future<Result<void>> changeSettlementAccount(int newAccountId) async =>
      const Result.failure(
        Failure(
          code: 'transaction_owner_unknown',
          message: 'This transaction belongs to an unknown business owner.',
        ),
      );

  @override
  Future<Result<void>> changeOccurredAt(DateTime newTime) async =>
      const Result.failure(
        Failure(
          code: 'transaction_owner_unknown',
          message: 'This transaction belongs to an unknown business owner.',
        ),
      );

  @override
  Future<Result<void>> changeNote(String? newNote) {
    return _service.updateTransactionMetadata(
      UpdateTransactionMetadataCommand(
        transactionId: _transactionId,
        note: newNote == null
            ? const Patch<String>.clear()
            : Patch.set(newNote),
      ),
    );
  }

  @override
  EditPermission canEdit(EditableField field) {
    return switch (field) {
      EditableField.note => const EditPermission.allowed(),
      _ => const EditPermission.denied(reason: '该交易属于当前版本未识别的业务来源，仅允许修改备注'),
    };
  }

  @override
  String? displayBanner() => '该交易属于当前版本未识别的业务来源：$_ownerType';
}
