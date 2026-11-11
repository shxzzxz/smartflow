import '../../../../core/money/money.dart';
import '../../../../domain/insurance/entity/insured_person.dart';
import '../../../../domain/insurance/port/commercial_insurance_repository.dart';
import '../../../../domain/insurance/port/insured_person_repository.dart';
import '../../../../domain/insurance/port/social_insurance_repository.dart';
import '../../../../domain/insurance/valobj/insurance_enums.dart';
import 'insurance_coverage_read_models.dart';

abstract interface class InsuranceCoverageQueryService {
  Future<InsuranceOverview> insuranceOverview();
  Future<List<InsuranceMemberListItem>> listMembers();
  Future<List<CommercialInsuranceListItem>> listCommercialInsurances();
  Future<List<InsuredPerson>> listInsuredPeople();
  Future<MemberCoverageOverview?> memberCoverage(String insuredPersonId);
  Future<CommercialInsuranceDetail?> commercialInsuranceDetail(
    String insuranceId,
  );
  Future<SocialInsuranceDetail?> socialInsuranceDetail(String insuranceId);
}

class InsuranceCoverageQueryServiceImpl
    implements InsuranceCoverageQueryService {
  InsuranceCoverageQueryServiceImpl({
    required InsuredPersonRepository insuredPeople,
    required CommercialInsuranceRepository commercialInsurances,
    required SocialInsuranceRepository socialInsurances,
    DateTime Function()? now,
  }) : _insuredPeople = insuredPeople,
       _commercialInsurances = commercialInsurances,
       _socialInsurances = socialInsurances,
       _now = now ?? DateTime.now;

  final InsuredPersonRepository _insuredPeople;
  final CommercialInsuranceRepository _commercialInsurances;
  final SocialInsuranceRepository _socialInsurances;
  final DateTime Function() _now;

  @override
  Future<InsuranceOverview> insuranceOverview() async {
    final members = await listMembers();
    final commercialInsurances = await listCommercialInsurances();
    final activePolicies = commercialInsurances
        .where((item) => _isInForce(item.status))
        .toList(growable: false);
    final coveredPersonIds = <String>{
      for (final policy in activePolicies)
        for (final personId in policy.insurance.insuredPersonIds) personId,
    };

    var coverageAmountTotal = Money.zero();
    for (final policy in activePolicies) {
      final amount = policy.insurance.coverageAmount?.amount ?? Money.zero();
      for (
        var index = 0;
        index < policy.insurance.insuredPersonIds.length;
        index++
      ) {
        coverageAmountTotal += amount;
      }
    }

    return InsuranceOverview(
      members: members,
      commercialInsurances: commercialInsurances,
      activePolicyCount: activePolicies.length,
      coveredMemberCount: coveredPersonIds.length,
      coverageAmountTotal: coverageAmountTotal,
    );
  }

  @override
  Future<List<InsuranceMemberListItem>> listMembers() async {
    final people = await _insuredPeople.list();
    final commercial = await _commercialInsurances.list();
    final social = await _socialInsurances.list();
    final counts = <String, int>{};
    for (final insurance in commercial) {
      for (final personId in insurance.insuredPersonIds) {
        counts[personId] = (counts[personId] ?? 0) + 1;
      }
    }
    final socialPeople = {
      for (final insurance in social) insurance.insuredPersonId,
    };
    final asOf = _now();
    return [
      for (final person in people)
        InsuranceMemberListItem(
          insuredPersonId: person.id,
          name: person.name,
          relationship: person.relationship,
          gender: person.gender,
          avatarPreset: person.avatarPreset,
          age: person.ageAt(asOf),
          commercialInsuranceCount: counts[person.id] ?? 0,
          hasSocialInsurance: socialPeople.contains(person.id),
        ),
    ];
  }

  @override
  Future<List<CommercialInsuranceListItem>> listCommercialInsurances() async {
    final insurances = await _commercialInsurances.list();
    final people = await _insuredPeople.list();
    final peopleById = {for (final person in people) person.id: person};
    final asOf = _now();
    return [
      for (final insurance in insurances)
        CommercialInsuranceListItem(
          insurance: insurance,
          insuredPeople: [
            for (final personId in insurance.insuredPersonIds)
              ?peopleById[personId],
          ],
          status: insurance.statusAt(asOf),
        ),
    ];
  }

  @override
  Future<List<InsuredPerson>> listInsuredPeople() => _insuredPeople.list();

  @override
  Future<MemberCoverageOverview?> memberCoverage(String insuredPersonId) async {
    final person = await _insuredPeople.find(insuredPersonId);
    if (person == null) return null;
    final asOf = _now();
    return MemberCoverageOverview(
      insuredPerson: person,
      age: person.ageAt(asOf),
      commercialInsurances: await _commercialInsurances.list(
        insuredPersonId: insuredPersonId,
      ),
      socialInsurances: await _socialInsurances.list(
        insuredPersonId: insuredPersonId,
      ),
      asOf: asOf,
    );
  }

  @override
  Future<CommercialInsuranceDetail?> commercialInsuranceDetail(
    String insuranceId,
  ) async {
    final insurance = await _commercialInsurances.find(insuranceId);
    if (insurance == null) return null;
    final peopleById = {
      for (final person in await _insuredPeople.list()) person.id: person,
    };
    final people = <InsuredPerson>[];
    for (final personId in insurance.insuredPersonIds) {
      final person = peopleById[personId];
      if (person != null) people.add(person);
    }
    return CommercialInsuranceDetail(
      insurance: insurance,
      insuredPeople: people,
      status: insurance.statusAt(_now()),
      asOf: _now(),
    );
  }

  @override
  Future<SocialInsuranceDetail?> socialInsuranceDetail(
    String insuranceId,
  ) async {
    final insurance = await _socialInsurances.find(insuranceId);
    if (insurance == null) return null;
    final person = await _insuredPeople.find(insurance.insuredPersonId);
    if (person == null) return null;
    return SocialInsuranceDetail(insurance: insurance, insuredPerson: person);
  }
}

bool _isInForce(InsuranceCoverageStatus status) {
  return status == InsuranceCoverageStatus.active ||
      status == InsuranceCoverageStatus.lifetime;
}
