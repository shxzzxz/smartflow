import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/port/advance_case_repository.dart';
import 'package:smartflow/domain/orchestration/service/advance_transaction_fact_policy.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/shared/business_activity/business_activity_item_key.dart';
import 'package:smartflow/shared/business_activity/business_activity_item_role.dart';

import 'advance_business_activity_item_query.dart';

class AdvanceCaseQueryService {
  const AdvanceCaseQueryService({required AdvanceCaseRepository repository})
    : _repository = repository;

  final AdvanceCaseRepository _repository;

  Future<AdvanceCase?> findById(String id) => _repository.findById(id);

  Future<Map<String, AdvanceCase>> findByIds(Set<String> ids) =>
      _repository.findByIds(ids);

  Stream<AdvanceCase?> watchById(String id) => _repository.watchById(id);

  Future<Map<String, AdvanceBusinessActivityItemProjection>>
  findBusinessActivityItems(
    Map<String, AdvanceBusinessActivityItemRequest> requests,
  ) async {
    if (requests.isEmpty) return const {};
    final cases = await findByIds({
      for (final request in requests.values) request.advanceCaseId,
    });
    final items = <String, AdvanceBusinessActivityItemProjection>{};
    for (final entry in requests.entries) {
      final advanceCase = cases[entry.value.advanceCaseId];
      if (advanceCase == null) continue;
      final factKind = resolveAdvanceTransactionFactKind(
        entry.value.businessPurpose,
      );
      if (factKind == null) continue;
      final isOrigin = factKind == AdvanceTransactionFactKind.advance;
      items[entry.key] = AdvanceBusinessActivityItemProjection(
        transactionId: entry.key,
        advanceCaseId: entry.value.advanceCaseId,
        itemKey: isOrigin
            ? BusinessActivityItemKey(
                type: orchestrationAdvanceOwnerType,
                id: entry.value.advanceCaseId,
              )
            : BusinessActivityItemKey.transaction(entry.key),
        factKind: factKind,
        role: isOrigin
            ? BusinessActivityItemRole.origin
            : BusinessActivityItemRole.followUp,
        scenario: advanceCase.scenario,
        trackingMode: advanceCase.trackingMode,
      );
    }
    return items;
  }
}
