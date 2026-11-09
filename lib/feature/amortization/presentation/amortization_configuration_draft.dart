import '../../../domain/orchestration/valobj/amortization_enums.dart';

class AmortizationConfigurationDraft {
  const AmortizationConfigurationDraft({
    required this.firstRecognitionAt,
    required this.cadenceUnit,
    required this.cadenceInterval,
    required this.recognitionCount,
  });

  factory AmortizationConfigurationDraft.defaultFor(DateTime occurredAt) {
    final month = DateTime(occurredAt.year, occurredAt.month + 1);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return AmortizationConfigurationDraft(
      firstRecognitionAt: DateTime(
        month.year,
        month.month,
        occurredAt.day > lastDay ? lastDay : occurredAt.day,
      ),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      recognitionCount: 1,
    );
  }

  final DateTime firstRecognitionAt;
  final AmortizationCadenceUnit cadenceUnit;
  final int cadenceInterval;
  final int recognitionCount;
}
