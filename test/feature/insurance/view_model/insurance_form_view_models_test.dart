import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/insurance/coverage_overview/query/insurance_coverage_query_service.dart';
import 'package:smartflow/application/insurance/coverage_overview/query/insurance_coverage_read_models.dart';
import 'package:smartflow/domain/insurance/entity/insured_person.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/feature/insurance/view_model/commercial_insurance_form_view_model.dart';
import 'package:smartflow/feature/insurance/view_model/insured_person_form_view_model.dart';
import 'package:smartflow/feature/insurance/view_model/social_insurance_form_view_model.dart';

void main() {
  test(
    'form view models retain edits when the query source refreshes',
    () async {
      final person = InsuredPerson(
        id: 'person-1',
        name: '张一',
        birthDate: DateTime(1990, 6, 15),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final query = _FakeInsuranceCoverageQueryService([person]);
      final querySource = Provider<InsuranceCoverageQueryService>(
        (ref) => query,
      );
      final container = ProviderContainer(
        overrides: [
          insuranceCoverageQueryServiceProvider.overrideWith(
            (ref) => ref.watch(querySource),
          ),
        ],
      );
      addTearDown(container.dispose);

      final commercial = commercialInsuranceFormViewModelProvider(
        null,
        'person-1',
      );
      final social = socialInsuranceFormViewModelProvider(null, 'person-1');
      final insuredPerson = insuredPersonFormViewModelProvider('person-1');
      await container.read(commercial.future);
      await container.read(social.future);
      await container.read(insuredPerson.future);

      container
          .read(commercial.notifier)
          .setCategory(CommercialInsuranceCategory.accident);
      container
          .read(social.notifier)
          .setParticipantType(SocialParticipantType.resident);
      container
          .read(insuredPerson.notifier)
          .setRelationship(MemberRelationship.spouse);

      container.invalidate(querySource);

      expect(
        (await container.read(commercial.future))!.category,
        CommercialInsuranceCategory.accident,
      );
      expect(
        (await container.read(social.future))!.participantType,
        SocialParticipantType.resident,
      );
      expect(
        (await container.read(insuredPerson.future))!.relationship,
        MemberRelationship.spouse,
      );
    },
  );
}

class _FakeInsuranceCoverageQueryService
    implements InsuranceCoverageQueryService {
  const _FakeInsuranceCoverageQueryService(this.people);

  final List<InsuredPerson> people;

  @override
  Future<List<InsuredPerson>> listInsuredPeople() async => people;

  @override
  Future<InsuranceOverview> insuranceOverview() => throw UnimplementedError();

  @override
  Future<List<InsuranceMemberListItem>> listMembers() =>
      throw UnimplementedError();

  @override
  Future<List<CommercialInsuranceListItem>> listCommercialInsurances() =>
      throw UnimplementedError();

  @override
  Future<MemberCoverageOverview?> memberCoverage(String insuredPersonId) =>
      throw UnimplementedError();

  @override
  Future<CommercialInsuranceDetail?> commercialInsuranceDetail(
    String insuranceId,
  ) => throw UnimplementedError();

  @override
  Future<SocialInsuranceDetail?> socialInsuranceDetail(String insuranceId) =>
      throw UnimplementedError();
}
