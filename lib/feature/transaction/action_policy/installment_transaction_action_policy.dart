import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import 'package:smartflow/application/credit/credit_api.dart';
import 'transaction_action_policy.dart';

/// 分期业务域针对单笔交易的 action policy。
///
/// 职责限定为"按 `ownerRole` 把通用 UI 的 universal 动作路由到 `InstallmentService`
/// 的领域入口"——所有写入与一致性逻辑都在 service 内部，policy 不再持有
/// fallback 也不直接调 PostingAppService。
///
/// 路由表：
/// - 删除：disbursement 走 `deleteContract`；其余走 `revertRepayment`。
/// - 改账户/时间/备注：disbursement 走 `updateContract`；其余走 `editRepayment`。
/// - 金额修改一律禁止；改动入口在合同详情页/还款表单。
class InstallmentTransactionActionPolicy implements TransactionActionPolicy {
  const InstallmentTransactionActionPolicy({
    required InstallmentService installment,
    required int contractId,
    required InstallmentOwnerRole ownerRole,
    required int transactionId,
  }) : _installment = installment,
       _contractId = contractId,
       _ownerRole = ownerRole,
       _transactionId = transactionId;

  final InstallmentService _installment;
  final int _contractId;
  final InstallmentOwnerRole _ownerRole;
  final int _transactionId;

  @override
  Future<Result<void>> delete() {
    return switch (_ownerRole) {
      InstallmentOwnerRole.disbursement => _installment.deleteContract(
        DeleteContractCommand(contractId: _contractId),
      ),
      InstallmentOwnerRole.scheduledRepayment ||
      InstallmentOwnerRole.extraPrincipal ||
      InstallmentOwnerRole.earlySettlement => _installment.revertRepayment(
        RevertRepaymentCommand(transactionId: _transactionId),
      ),
    };
  }

  @override
  String editRoutePath() => '/installments/$_contractId';

  @override
  Future<Result<void>> changeSettlementAccount(int newAccountId) {
    return switch (_ownerRole) {
      InstallmentOwnerRole.disbursement => _installment.updateContract(
        UpdateContractCommand(
          contractId: _contractId,
          disbursementAccountId: newAccountId,
        ),
      ),
      InstallmentOwnerRole.scheduledRepayment ||
      InstallmentOwnerRole.extraPrincipal ||
      InstallmentOwnerRole.earlySettlement => _installment.editRepayment(
        EditRepaymentCommand(
          transactionId: _transactionId,
          contractId: _contractId,
          paidFromAccountId: newAccountId,
        ),
      ),
    };
  }

  @override
  Future<Result<void>> changeOccurredAt(DateTime newTime) {
    return switch (_ownerRole) {
      InstallmentOwnerRole.disbursement => _installment.updateContract(
        UpdateContractCommand(contractId: _contractId, borrowingDate: newTime),
      ),
      InstallmentOwnerRole.scheduledRepayment ||
      InstallmentOwnerRole.extraPrincipal ||
      InstallmentOwnerRole.earlySettlement => _installment.editRepayment(
        EditRepaymentCommand(
          transactionId: _transactionId,
          contractId: _contractId,
          occurredAt: newTime,
        ),
      ),
    };
  }

  @override
  Future<Result<void>> changeNote(String? newNote) {
    final Patch<String> notePatch =
        newNote == null ? const Patch.clear() : Patch.set(newNote);
    return switch (_ownerRole) {
      InstallmentOwnerRole.disbursement => _installment.updateContract(
        UpdateContractCommand(contractId: _contractId, note: notePatch),
      ),
      InstallmentOwnerRole.scheduledRepayment ||
      InstallmentOwnerRole.extraPrincipal ||
      InstallmentOwnerRole.earlySettlement => _installment.editRepayment(
        EditRepaymentCommand(
          transactionId: _transactionId,
          contractId: _contractId,
          note: notePatch,
        ),
      ),
    };
  }

  @override
  EditPermission canEdit(EditableField field) {
    return switch (field) {
      EditableField.amount => const EditPermission.denied(
        reason: '请在分期合同详情页修改金额',
      ),
      _ => const EditPermission.allowed(),
    };
  }

  @override
  String? displayBanner() {
    return switch (_ownerRole) {
      InstallmentOwnerRole.disbursement => '此为分期合同放款，金额、账户、日期等需在合同详情页内调整',
      InstallmentOwnerRole.scheduledRepayment => '此为分期期次还款，撤销请在合同详情页操作',
      InstallmentOwnerRole.extraPrincipal => '此为分期提前还本，撤销请在合同详情页操作',
      InstallmentOwnerRole.earlySettlement => '此为分期提前结清，撤销请在合同详情页操作',
    };
  }
}
