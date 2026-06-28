import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';

part 'bill_query_providers.g.dart';

@riverpod
Future<List<BillSummaryReadModel>> billSummariesByAccount(
  Ref ref,
  String accountId,
) {
  return ref.watch(billQueryServiceProvider).listBillsByAccount(accountId);
}

@riverpod
Future<BillDetailReadModel?> billDetail(Ref ref, String billId) {
  return ref.watch(billQueryServiceProvider).findBillDetail(billId);
}
