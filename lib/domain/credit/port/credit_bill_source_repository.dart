abstract interface class CreditBillSourceRepository {
  Future<int> netConsumptionMinor({
    required String accountId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  });
}
