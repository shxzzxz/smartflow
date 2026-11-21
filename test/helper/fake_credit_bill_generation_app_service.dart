import 'package:smartflow/application/credit/credit_command_api.dart';

class FakeCreditBillGenerationAppService
    implements CreditBillGenerationAppService {
  FakeCreditBillGenerationAppService({
    this.onRefreshBill,
    this.onRefreshAccount,
  });

  final Future<void> Function(String billId)? onRefreshBill;
  final Future<void> Function(String accountId)? onRefreshAccount;
  final refreshedBills = <String>[];
  final refreshedAccounts = <String>[];

  @override
  Future<void> refreshBill(String billId) async {
    refreshedBills.add(billId);
    await onRefreshBill?.call(billId);
  }

  @override
  Future<void> refreshCurrentAndFutureBillsForAccount({
    required String accountId,
    required DateTime now,
  }) async {
    refreshedAccounts.add(accountId);
    await onRefreshAccount?.call(accountId);
  }

  @override
  Future<void> generateDueBills({required DateTime now}) async {}

  @override
  Future<void> generateDueBillsForAccount({
    required String accountId,
    required DateTime now,
  }) async {}

  @override
  Future<void> generateBillForPeriod({
    required String accountId,
    required BillPeriod period,
    required DateTime now,
  }) async {}

  @override
  Future<void> deleteBill(String billId) async {}

  @override
  Future<void> updateBillWindow({
    required String billId,
    required DateTime startDate,
    required DateTime billingDate,
  }) async {}

  @override
  Future<void> updateConsumptionWindow({
    required String billId,
    required String billItemId,
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) async {}
}
