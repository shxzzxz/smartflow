import 'transaction_ownership.dart';

/// 垫付的业务管理方式。它只决定 owner 聚合类型，不改变过账规则。
enum AdvanceManagement { itemized, account }

/// 垫付的业务场景。它是 owner 下的封闭枚举，不进入 [BusinessPurpose]。
enum AdvanceScenario { aa, onBehalf, reimbursement }

/// 垫付结清时，剩余应收无法收回的性质。
enum AdvanceShortfallKind { selfBorne, badDebt }

extension AdvanceManagementBehavior on AdvanceManagement {
  String get ownerType => switch (this) {
    AdvanceManagement.itemized => 'advance.itemized',
    AdvanceManagement.account => 'advance.account',
  };
}

TransactionOwnership advanceOwnership({
  required AdvanceManagement management,
  required String ownerId,
  required AdvanceScenario scenario,
}) {
  return TransactionOwnership(
    ownerType: management.ownerType,
    ownerId: ownerId,
    ownerRole: scenario.name,
  );
}

extension AdvanceTransactionOwnership on TransactionOwnership {
  AdvanceManagement? get advanceManagement {
    for (final management in AdvanceManagement.values) {
      if (ownerType == management.ownerType) return management;
    }
    return null;
  }

  AdvanceScenario? get advanceScenario {
    if (advanceManagement == null) return null;
    for (final scenario in AdvanceScenario.values) {
      if (ownerRole == scenario.name) return scenario;
    }
    return null;
  }

  bool get isAdvance => advanceManagement != null;
}
