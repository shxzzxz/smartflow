import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/providers.dart';
import '../../../domain/accounting/accounting_api.dart';
import '../../../domain/credit/enums/installment_enums.dart';
import '../action_policy/default_transaction_action_policy.dart';
import '../action_policy/installment_transaction_action_policy.dart';
import '../action_policy/transaction_action_policy.dart';

part 'transaction_action_policy_provider.g.dart';

/// 交易详情页据此获取该笔交易适用的 action policy。
///
/// policy 按 `transaction.owner_type` 预解析，UI 不再按业务模块分流。
/// 这里属于 features 集成层——TransactionActionPolicy 的本质是 UI 接入业务域
/// 的统一契约，不属于任何业务域；详见 docs/08.2。
@riverpod
TransactionActionPolicy transactionActionPolicy(
  Ref ref,
  Transaction transaction,
) {
  final ownership = transaction.ownership;
  if (ownership == null) {
    return DefaultTransactionActionPolicy(
      service: ref.watch(transactionServiceProvider),
      transactionId: transaction.id,
      businessPurpose: transaction.businessPurpose,
    );
  }

  if (ownership.ownerType == installmentOwnerType &&
      ownership.ownerId != null) {
    final role = InstallmentOwnerRole.fromWire(ownership.ownerRole);
    if (role != null) {
      return InstallmentTransactionActionPolicy(
        installment: ref.watch(installmentServiceProvider),
        contractId: ownership.ownerId!,
        ownerRole: role,
        transactionId: transaction.id,
      );
    }
  }

  return UnknownOwnedTransactionActionPolicy(
    service: ref.watch(transactionServiceProvider),
    transactionId: transaction.id,
    ownerType: ownership.ownerType,
  );
}
