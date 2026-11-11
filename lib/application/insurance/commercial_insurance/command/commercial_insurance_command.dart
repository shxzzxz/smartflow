import '../../../../domain/insurance/valobj/coverage_amount.dart';
import '../../../../domain/insurance/valobj/coverage_term.dart';
import '../../../../domain/insurance/valobj/insurance_enums.dart';
import '../../../../domain/insurance/valobj/premium_plan.dart';

class InsuranceResponsibilityPointInput {
  const InsuranceResponsibilityPointInput({
    this.id,
    required this.label,
    required this.value,
  });

  final String? id;
  final String label;
  final String value;
}

class InsuranceResponsibilityInput {
  const InsuranceResponsibilityInput({
    this.id,
    required this.kind,
    required this.name,
    required this.points,
  });

  final String? id;
  final ResponsibilityKind kind;
  final String name;
  final List<InsuranceResponsibilityPointInput> points;
}

class SaveCommercialInsuranceCommand {
  const SaveCommercialInsuranceCommand({
    this.id,
    required this.name,
    required this.insurerName,
    required this.category,
    this.productForm,
    required this.coverageTerm,
    this.coverageAmount,
    this.premiumPlan,
    required this.insuredPersonIds,
    this.responsibilities,
  });

  final String? id;
  final String name;
  final String insurerName;
  final CommercialInsuranceCategory category;
  final String? productForm;
  final CoverageTerm coverageTerm;
  final CoverageAmount? coverageAmount;
  final PremiumPlan? premiumPlan;
  final List<String> insuredPersonIds;

  /// `null` keeps the responsibilities currently stored on an existing policy.
  final List<InsuranceResponsibilityInput>? responsibilities;
}
