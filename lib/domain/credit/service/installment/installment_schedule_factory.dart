import '../../entity/installment_schedule.dart';
import '../../valobj/installment_enums.dart';
import 'installment_plan_engine.dart';

class InstallmentScheduleFactory {
  const InstallmentScheduleFactory();

  List<InstallmentSchedule> fromEntries({
    required String contractId,
    required List<InstallmentSchedulePlanEntry> entries,
    required DateTime createdAt,
    required String Function() newId,
    Map<int, String> stageIdsByPeriod = const {},
  }) => [
    for (final entry in entries)
      InstallmentSchedule(
        id: newId(),
        contractId: contractId,
        stageId: stageIdsByPeriod[entry.periodNo],
        periodNo: entry.periodNo,
        expectedRepaymentDate: entry.expectedRepaymentDate,
        expectedPrincipal: entry.expectedPrincipal,
        expectedInterest: entry.expectedInterest,
        expectedFee: entry.expectedFee,
        status: InstallmentScheduleStatus.pending,
        createdAt: createdAt,
      ),
  ];
}
