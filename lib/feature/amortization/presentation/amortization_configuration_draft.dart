import '../../../domain/orchestration/valobj/amortization_enums.dart';

class AmortizationConfigurationDraft {
  const AmortizationConfigurationDraft({
    required this.firstRecognitionAt,
    required this.cadenceUnit,
    required this.cadenceInterval,
    required this.recognitionCount,
  });

  final DateTime firstRecognitionAt;
  final AmortizationCadenceUnit cadenceUnit;
  final int cadenceInterval;
  final int recognitionCount;
}
