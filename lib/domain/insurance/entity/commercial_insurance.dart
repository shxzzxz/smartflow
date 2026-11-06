import '../valobj/coverage_amount.dart';
import '../valobj/coverage_responsibility.dart';
import '../valobj/coverage_term.dart';
import '../valobj/insurance_attachment.dart';
import '../valobj/insurance_enums.dart';
import '../valobj/premium_plan.dart';

class CommercialInsurance {
  CommercialInsurance({
    required this.id,
    required String name,
    required String insurerName,
    required this.category,
    String? productForm,
    required this.coverageTerm,
    this.coverageAmount,
    this.premiumPlan,
    required List<String> insuredPersonIds,
    required List<CoverageResponsibility> responsibilities,
    required List<InsuranceAttachment> attachments,
    required this.createdAt,
    required this.updatedAt,
  }) : name = name.trim(),
       insurerName = insurerName.trim(),
       productForm = productForm?.trim(),
       insuredPersonIds = List.unmodifiable(insuredPersonIds),
       responsibilities = List.unmodifiable(responsibilities),
       attachments = List.unmodifiable(attachments);

  final String id;
  final String name;
  final String insurerName;
  final CommercialInsuranceCategory category;
  final String? productForm;
  final CoverageTerm coverageTerm;
  final CoverageAmount? coverageAmount;
  final PremiumPlan? premiumPlan;
  final List<String> insuredPersonIds;
  final List<CoverageResponsibility> responsibilities;
  final List<InsuranceAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  InsuranceCoverageStatus statusAt(DateTime date) =>
      coverageTerm.statusAt(date);

  void validate() {
    if (id.trim().isEmpty || name.isEmpty || insurerName.isEmpty) {
      throw ArgumentError('Commercial insurance basic fields are required.');
    }
    if (insuredPersonIds.isEmpty) {
      throw ArgumentError('Commercial insurance requires an insured person.');
    }
    if (insuredPersonIds.toSet().length != insuredPersonIds.length ||
        insuredPersonIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Insured person ids must be non-empty and unique.');
    }
    coverageTerm.validate();
    coverageAmount?.validate();
    premiumPlan?.validate();

    final responsibilityIds = <String>{};
    for (final responsibility in responsibilities) {
      responsibility.validate();
      if (!responsibilityIds.add(responsibility.id)) {
        throw ArgumentError('Duplicate coverage responsibility id.');
      }
    }
    final attachmentIds = <String>{};
    for (final attachment in attachments) {
      attachment.validate();
      if (!attachmentIds.add(attachment.id)) {
        throw ArgumentError('Duplicate insurance attachment id.');
      }
    }
  }
}
