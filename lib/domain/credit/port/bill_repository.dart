import '../entity/bill.dart';
import '../valobj/bill_period.dart';

abstract interface class BillRepository {
  Future<Bill?> findBill(String billId);

  Future<Bill?> findByAccountAndPeriod(String accountId, BillPeriod period);

  Future<List<Bill>> listBillsByAccount(String accountId);

  Future<Bill> saveBill(Bill bill);

  Future<void> updateBill(Bill bill);

  Future<void> replaceBillItems(String billId, List<BillItem> items);

  Future<bool> hasUnsettledItems(String accountId);
}
