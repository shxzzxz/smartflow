import '../../../core/error/failure.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../application/ledger/ledger_command_api.dart';
import 'transaction_action_policy.dart';

/// 普通交易的默认 policy：将 universal 动作路由到对应账务应用服务。
class DefaultTransactionActionPolicy implements TransactionActionPolicy {
  const DefaultTransactionActionPolicy({
    required TransactionCorrectionAppService correctionService,
    required TransactionUpdateAppService updateService,
    required String transactionId,
    required BusinessPurpose businessPurpose,
  }) : _correctionService = correctionService,
       _updateService = updateService,
       _transactionId = transactionId,
       _businessPurpose = businessPurpose;

  final TransactionCorrectionAppService _correctionService;
  final TransactionUpdateAppService _updateService;
  final String _transactionId;
  final BusinessPurpose _businessPurpose;

  @override
  Future<Result<void>> delete() {
    return _correctionService.deleteTransaction(
      DeleteTransactionCommand(transactionId: _transactionId),
    );
  }

  @override
  String editRoutePath() {
    return switch (_businessPurpose) {
      BusinessPurpose.debtRepayment =>
        '/transaction/$_transactionId/repayment/edit',
      _ => '/transaction/$_transactionId/edit',
    };
  }

  @override
  Future<Result<void>> changeSettlementAccount(String newAccountId) async {
    return const Result.failure(
      Failure(
        code: 'settlement_account_update_requires_correction',
        message: 'Settlement account changes must use transaction correction.',
      ),
    );
  }

  @override
  Future<Result<void>> changeOccurredAt(DateTime newTime) async {
    final result = await _updateService.updateBasicInfo(
      UpdateTransactionBasicInfoCommand(
        transactionId: _transactionId,
        occurredAt: newTime,
      ),
    );
    return _voidResult(result);
  }

  @override
  Future<Result<void>> changeNote(String? newNote) async {
    final result = await _updateService.updateBasicInfo(
      UpdateTransactionBasicInfoCommand(
        transactionId: _transactionId,
        note:
            newNote == null
                ? const Patch<String?>.clear()
                : Patch<String?>.set(newNote),
      ),
    );
    return _voidResult(result);
  }

  @override
  EditPermission canEdit(EditableField field) {
    return switch (field) {
      EditableField.settlementAccount => const EditPermission.denied(
        reason: '结算账户变更需要通过更正交易完成',
      ),
      _ => const EditPermission.allowed(),
    };
  }

  @override
  String? displayBanner() => null;
}

class UnknownOwnedTransactionActionPolicy implements TransactionActionPolicy {
  const UnknownOwnedTransactionActionPolicy({
    required TransactionUpdateAppService updateService,
    required String transactionId,
    required String ownerType,
  }) : _updateService = updateService,
       _transactionId = transactionId,
       _ownerType = ownerType;

  final TransactionUpdateAppService _updateService;
  final String _transactionId;
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
  Future<Result<void>> changeSettlementAccount(String newAccountId) async =>
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
  Future<Result<void>> changeNote(String? newNote) async {
    final result = await _updateService.updateBasicInfo(
      UpdateTransactionBasicInfoCommand(
        transactionId: _transactionId,
        note:
            newNote == null
                ? const Patch<String?>.clear()
                : Patch<String?>.set(newNote),
      ),
    );
    return _voidResult(result);
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

Result<void> _voidResult<T>(Result<T> result) {
  return switch (result) {
    Success<T>() => const Result.success(null),
    FailureResult<T>(:final failure) => Result.failure(failure),
  };
}
