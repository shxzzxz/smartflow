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
    this.description,
    required this.points,
  });

  final String? id;
  final ResponsibilityKind kind;
  final String name;
  final String? description;
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
    this.coverageAmountDescription,
    this.coverageSummary,
    this.coverageHighlights,
    this.policyholderName,
    this.beneficiaryDescription,
    this.waitingPeriodDescription,
    this.exclusionsDescription,
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

  /// `null` preserves the current description; an empty string clears it.
  final String? coverageAmountDescription;

  /// `null` preserves the current summary; an empty string clears it.
  final String? coverageSummary;

  /// `null` preserves the current highlights; an empty string clears them.
  final String? coverageHighlights;

  /// Contract text fields preserve existing values when omitted and clear them
  /// when supplied as blank strings.
  final String? policyholderName;
  final String? beneficiaryDescription;
  final String? waitingPeriodDescription;
  final String? exclusionsDescription;

  /// `null` preserves the current plan. Use the dedicated payment
  /// configuration operation to clear it.
  final PremiumPlan? premiumPlan;
  final List<String> insuredPersonIds;

  /// `null` keeps the responsibilities currently stored on an existing policy.
  final List<InsuranceResponsibilityInput>? responsibilities;
}
