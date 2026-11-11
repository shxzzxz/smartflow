import '../../../../core/money/money.dart';
import '../../../../domain/insurance/entity/commercial_insurance.dart';
import '../../../../domain/insurance/entity/insured_person.dart';
import '../../../../domain/insurance/entity/social_insurance.dart';
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
    required this.hasSocialInsurance,
  });

  final String insuredPersonId;
  final String name;
  final MemberRelationship relationship;
  final MemberGender gender;
  final MemberAvatarPreset avatarPreset;
  final int age;
  final int commercialInsuranceCount;
  final bool hasSocialInsurance;
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
    required this.socialInsurances,
    required this.asOf,
  });

  final InsuredPerson insuredPerson;
  final int age;
  final List<CommercialInsurance> commercialInsurances;
  final List<SocialInsurance> socialInsurances;
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
    for (final insurance in socialInsurances)
      InsuranceListItem(
        sourceType: InsuranceSourceType.social,
        insuranceId: insurance.id,
        title: '社保${insurance.insuranceType.label}',
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
    required this.asOf,
  });

  final CommercialInsurance insurance;
  final List<InsuredPerson> insuredPeople;
  final InsuranceCoverageStatus status;
  final DateTime asOf;
}

class SocialInsuranceDetail {
  const SocialInsuranceDetail({
    required this.insurance,
    required this.insuredPerson,
  });

  final SocialInsurance insurance;
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
