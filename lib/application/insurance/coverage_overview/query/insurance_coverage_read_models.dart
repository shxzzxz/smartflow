import '../../../../core/money/money.dart';
import '../../../../domain/insurance/entity/commercial_insurance.dart';
import '../../../../domain/insurance/entity/insured_person.dart';
import '../../../../domain/insurance/entity/social_medical_insurance.dart';
import '../../../../domain/insurance/entity/social_pension_insurance.dart';
import '../../../../domain/insurance/valobj/insurance_enums.dart';

class InsuranceMemberListItem {
  const InsuranceMemberListItem({
    required this.insuredPersonId,
    required this.name,
    required this.relationship,
    required this.gender,
    required this.avatarPreset,
    required this.age,
    required this.commercialInsuranceCount,
    required this.hasSocialMedical,
    required this.hasSocialPension,
  });

  final String insuredPersonId;
  final String name;
  final MemberRelationship relationship;
  final MemberGender gender;
  final MemberAvatarPreset avatarPreset;
  final int age;
  final int commercialInsuranceCount;
  final bool hasSocialMedical;
  final bool hasSocialPension;
}

class InsuranceListItem {
  const InsuranceListItem({
    required this.sourceType,
    required this.insuranceId,
    required this.title,
    required this.subtitle,
    required this.summary,
  });

  final InsuranceSourceType sourceType;
  final String insuranceId;
  final String title;
  final String subtitle;
  final String summary;
}

class CommercialInsuranceListItem {
  const CommercialInsuranceListItem({
    required this.insurance,
    required this.insuredPeople,
    required this.status,
  });

  final CommercialInsurance insurance;
  final List<InsuredPerson> insuredPeople;
  final InsuranceCoverageStatus status;

  String get insuredPeopleLabel =>
      insuredPeople.map((person) => person.name).join('、');
}

class InsuranceOverview {
  const InsuranceOverview({
    required this.members,
    required this.commercialInsurances,
    required this.activePolicyCount,
    required this.coveredMemberCount,
    required this.coverageAmountTotal,
  });

  final List<InsuranceMemberListItem> members;
  final List<CommercialInsuranceListItem> commercialInsurances;
  final int activePolicyCount;
  final int coveredMemberCount;

  /// 每名被保险人的在保障保单保额之和；共享保单会按成员分别累计。
  final Money coverageAmountTotal;
}

class MemberCoverageOverview {
  const MemberCoverageOverview({
    required this.insuredPerson,
    required this.age,
    required this.commercialInsurances,
    required this.socialMedicalInsurances,
    required this.socialPensionInsurances,
    required this.asOf,
  });

  final InsuredPerson insuredPerson;
  final int age;
  final List<CommercialInsurance> commercialInsurances;
  final List<SocialMedicalInsurance> socialMedicalInsurances;
  final List<SocialPensionInsurance> socialPensionInsurances;
  final DateTime asOf;

  int get activeCommercialInsuranceCount => commercialInsurances
      .where((insurance) => _isInForce(insurance.statusAt(asOf)))
      .length;

  Money get activeCoverageAmountTotal {
    var total = Money.zero();
    for (final insurance in commercialInsurances) {
      if (!_isInForce(insurance.statusAt(asOf))) continue;
      total += insurance.coverageAmount?.amount ?? Money.zero();
    }
    return total;
  }

  List<InsuranceListItem> get items => [
    for (final insurance in commercialInsurances)
      InsuranceListItem(
        sourceType: InsuranceSourceType.commercial,
        insuranceId: insurance.id,
        title: insurance.name,
        subtitle: '${insurance.insurerName} · ${insurance.category.label}',
        summary: _commercialSummary(insurance, asOf),
      ),
    for (final insurance in socialMedicalInsurances)
      InsuranceListItem(
        sourceType: InsuranceSourceType.socialMedical,
        insuranceId: insurance.id,
        title: InsuranceSourceType.socialMedical.label,
        subtitle: '${insurance.region} · ${insurance.participantType.label}',
        summary: '${insurance.contributionRecords.length} 条缴费记录',
      ),
    for (final insurance in socialPensionInsurances)
      InsuranceListItem(
        sourceType: InsuranceSourceType.socialPension,
        insuranceId: insurance.id,
        title: InsuranceSourceType.socialPension.label,
        subtitle: '${insurance.region} · ${insurance.participantType.label}',
        summary: '${insurance.contributionRecords.length} 条缴费记录',
      ),
  ];

  String _commercialSummary(CommercialInsurance insurance, DateTime asOf) {
    final parts = [insurance.statusAt(asOf).label];
    final amount = insurance.coverageAmount?.amount;
    if (amount != null) {
      parts.add('保额 ${_moneyLabel(amount)}');
    }
    return parts.join(' · ');
  }
}

class CommercialInsuranceDetail {
  const CommercialInsuranceDetail({
    required this.insurance,
    required this.insuredPeople,
    required this.status,
  });

  final CommercialInsurance insurance;
  final List<InsuredPerson> insuredPeople;
  final InsuranceCoverageStatus status;
}

class SocialMedicalInsuranceDetail {
  const SocialMedicalInsuranceDetail({
    required this.insurance,
    required this.insuredPerson,
  });

  final SocialMedicalInsurance insurance;
  final InsuredPerson insuredPerson;
}

class SocialPensionInsuranceDetail {
  const SocialPensionInsuranceDetail({
    required this.insurance,
    required this.insuredPerson,
  });

  final SocialPensionInsurance insurance;
  final InsuredPerson insuredPerson;
}

String _moneyLabel(Money money) {
  final value = money.format();
  return value.endsWith('.00') ? value.substring(0, value.length - 3) : value;
}

bool _isInForce(InsuranceCoverageStatus status) {
  return status == InsuranceCoverageStatus.active ||
      status == InsuranceCoverageStatus.lifetime;
}
