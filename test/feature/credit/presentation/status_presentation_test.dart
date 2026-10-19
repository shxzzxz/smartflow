import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/feature/credit/presentation/bill_status_presentation.dart';
import 'package:smartflow/feature/credit/presentation/contract_status_presentation.dart';

void main() {
  test('maps bill statuses to semantic badge presentations', () {
    final open = billStatusBadgePresentation(BillStatus.open);
    final billed = billStatusBadgePresentation(BillStatus.billed);
    final settled = billStatusBadgePresentation(BillStatus.settled);

    expect(open.label, '累积中');
    expect(open.tone, AppStatusTone.primary);
    expect(billed.label, '已出账');
    expect(billed.tone, AppStatusTone.warning);
    expect(settled.label, '已了结');
    expect(settled.tone, AppStatusTone.success);
  });

  test('maps contract statuses to semantic badge presentations', () {
    final active = contractStatusBadgePresentation(
      InstallmentContractStatus.active,
    );
    final settled = contractStatusBadgePresentation(
      InstallmentContractStatus.settled,
    );

    expect(active.label, '进行中');
    expect(active.tone, AppStatusTone.primary);
    expect(settled.label, '已结清');
    expect(settled.tone, AppStatusTone.success);
  });
}
