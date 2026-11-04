import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/orchestration/advance/query/advance_business_activity_item_query.dart';
import 'package:smartflow/application/orchestration/advance/query/advance_case_query_service.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/shared/business_activity/business_activity_item_key.dart';
import 'package:smartflow/shared/business_activity/business_activity_item_role.dart';

import '../../helper/fake_advance_case_repository.dart';

void main() {
  test(
    'advance facts expose item identity and role from the business domain',
    () async {
      final service = AdvanceCaseQueryService(
        repository: FakeAdvanceCaseRepository([
          const AdvanceCase(
            id: 'advance-1',
            scenario: AdvanceScenario.reimbursement,
            trackingMode: AdvanceTrackingMode.itemized,
          ),
        ]),
      );

      final items = await service.findBusinessActivityItems({
        'advance-tx': const AdvanceBusinessActivityItemRequest(
          advanceCaseId: 'advance-1',
          businessPurpose: BusinessPurpose.advance,
        ),
        'collection-tx': const AdvanceBusinessActivityItemRequest(
          advanceCaseId: 'advance-1',
          businessPurpose: BusinessPurpose.advanceCollection,
        ),
      });

      expect(
        items['advance-tx']!.itemKey,
        const BusinessActivityItemKey(
          type: orchestrationAdvanceOwnerType,
          id: 'advance-1',
        ),
      );
      expect(items['advance-tx']!.role, BusinessActivityItemRole.origin);
      expect(
        items['collection-tx']!.itemKey,
        const BusinessActivityItemKey.transaction('collection-tx'),
      );
      expect(items['collection-tx']!.role, BusinessActivityItemRole.followUp);
    },
  );
}
