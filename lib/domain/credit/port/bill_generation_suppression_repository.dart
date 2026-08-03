import '../valobj/bill_period.dart';

/// 记录用户不希望自动生成的账单账期。
abstract interface class BillGenerationSuppressionRepository {
  Future<bool> isSuppressed(String accountId, BillPeriod period);

  Future<void> suppress(String accountId, BillPeriod period);

  Future<void> clear(String accountId, BillPeriod period);
}
