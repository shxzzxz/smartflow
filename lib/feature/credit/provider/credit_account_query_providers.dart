import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';

part 'credit_account_query_providers.g.dart';

@riverpod
Future<CreditAccountOverviewReadModel?> creditAccountOverview(
  Ref ref,
  String accountId,
) {
  return ref.watch(creditAccountQueryServiceProvider).findOverview(accountId);
}
