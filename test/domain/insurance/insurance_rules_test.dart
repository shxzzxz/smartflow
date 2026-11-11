import 'package:test/test.dart';

import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/insurance/entity/commercial_insurance.dart';
import 'package:smartflow/domain/insurance/entity/insured_person.dart';
import 'package:smartflow/domain/insurance/entity/social_insurance.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_amount.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_responsibility.dart';
import 'package:smartflow/domain/insurance/valobj/coverage_term.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/domain/insurance/valobj/premium_plan.dart';
import 'package:smartflow/domain/insurance/valobj/social_contribution_record.dart';

void main() {
  group('InsuredPerson', () {
    test('derives age from the birth date', () {
      final person = InsuredPerson(
        id: 'person',
        name: '张三',
        birthDate: DateTime(1990, 6, 15),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(person.ageAt(DateTime(2026, 6, 14)), 35);
      expect(person.ageAt(DateTime(2026, 6, 15)), 36);
    });
  });

  group('CoverageTerm', () {
    final start = DateTime(2026, 6, 1);
    final end = DateTime(2026, 6, 30);

    test('derives coverage status from dates', () {
      final term = CoverageTerm(startDate: start, endDate: end);

      expect(
        term.statusAt(DateTime(2026, 5, 31)),
        InsuranceCoverageStatus.notStarted,
      );
      expect(
        term.statusAt(DateTime(2026, 6, 1)),
        InsuranceCoverageStatus.active,
      );
      expect(
        term.statusAt(DateTime(2026, 6, 30)),
        InsuranceCoverageStatus.active,
      );
      expect(
        term.statusAt(DateTime(2026, 7, 1)),
        InsuranceCoverageStatus.ended,
      );
    });

    test('keeps lifetime coverage independent from an end date', () {
      final term = CoverageTerm(startDate: start, lifetime: true);

      expect(term.statusAt(DateTime(1900)), InsuranceCoverageStatus.lifetime);
      expect(term.statusAt(DateTime(2100)), InsuranceCoverageStatus.lifetime);
      expect(
        () => CoverageTerm(
          startDate: start,
          endDate: end,
          lifetime: true,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects an end date before the start date', () {
      expect(
        () => CoverageTerm(
          startDate: start,
          endDate: DateTime(2026, 5, 31),
        ).validate(),
        throwsArgumentError,
      );
    });
  });

  group('coverage amounts and responsibilities', () {
    test('rejects negative coverage and premium amounts', () {
      expect(
        () => CoverageAmount(amount: Money(minorUnits: -1)).validate(),
        throwsArgumentError,
      );
      expect(
        () => PremiumPlan(
          frequency: PremiumFrequency.monthly,
          amount: Money(minorUnits: -1),
        ).validate(),
        throwsArgumentError,
      );
    });

    test('accepts descriptive names and requires unique point labels', () {
      expect(
        () => CoverageResponsibility(
          id: 'responsibility',
          kind: ResponsibilityKind.medical,
          name: '质子重离子医疗',
          points: const [],
          order: 0,
        ).validate(),
        returnsNormally,
      );
      expect(
        () => CoverageResponsibility(
          id: 'medical',
          kind: ResponsibilityKind.medical,
          name: '  ',
          points: const [],
          order: 0,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => CoverageResponsibility(
          id: 'medical',
          kind: ResponsibilityKind.medical,
          name: '医疗',
          points: const [
            ResponsibilityPoint(
              id: 'point-1',
              label: '住院',
              value: '10000',
              order: 0,
            ),
            ResponsibilityPoint(
              id: 'point-2',
              label: ' 住院 ',
              value: '20000',
              order: 1,
            ),
          ],
          order: 0,
        ).validate(),
        throwsArgumentError,
      );
    });
  });

  group('social contribution records', () {
    test('rejects duplicate months within one social insurance record', () {
      final record = SocialContributionRecord(
        month: MonthKey(year: 2026, month: 1),
        contributionBase: Money(minorUnits: 800000),
      );
      final insurance = SocialInsurance(
        id: 'medical',
        insuredPersonId: 'person',
        region: '上海',
        insuranceType: SocialInsuranceType.medical,
        participantType: SocialParticipantType.employee,
        contributionRecords: [record, record],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(insurance.validate, throwsArgumentError);
    });

    test('rejects negative contribution bases', () {
      final invalid = SocialContributionRecord(
        month: MonthKey(year: 2026, month: 1),
        contributionBase: Money(minorUnits: -1),
      );

      expect(invalid.validate, throwsArgumentError);
    });
  });

  group('CommercialInsurance', () {
    test('requires at least one unique insured person', () {
      CommercialInsurance build(List<String> personIds) => CommercialInsurance(
        id: 'insurance',
        name: '百万医疗',
        insurerName: '示例保险',
        category: CommercialInsuranceCategory.medical,
        coverageTerm: CoverageTerm(startDate: DateTime(2026, 1, 1)),
        insuredPersonIds: personIds,
        responsibilities: const [],
        attachments: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(build(const []).validate, throwsArgumentError);
      expect(build(const ['person', 'person']).validate, throwsArgumentError);
      expect(build(const ['person']).validate, returnsNormally);
    });
  });
}
