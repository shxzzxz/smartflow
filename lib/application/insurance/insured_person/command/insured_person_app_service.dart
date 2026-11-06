import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/insurance/entity/insured_person.dart';
import '../../../../domain/insurance/port/commercial_insurance_repository.dart';
import '../../../../domain/insurance/port/insured_person_repository.dart';
import '../../../../domain/insurance/port/social_insurance_repository.dart';
import '../../../../domain/insurance/valobj/insurance_error_code.dart';
import '../../../shared/transaction_runner.dart';
import 'insured_person_command.dart';

abstract interface class InsuredPersonAppService {
  Future<String> save(SaveInsuredPersonCommand command);
  Future<void> delete(String id);
}

class InsuredPersonAppServiceImpl implements InsuredPersonAppService {
  InsuredPersonAppServiceImpl({
    required InsuredPersonRepository insuredPeople,
    required CommercialInsuranceRepository commercialInsurances,
    required SocialInsuranceRepository socialInsurances,
    required TransactionRunner runner,
    required IdGenerator ids,
    DateTime Function()? now,
  }) : _insuredPeople = insuredPeople,
       _commercialInsurances = commercialInsurances,
       _socialInsurances = socialInsurances,
       _runner = runner,
       _ids = ids,
       _now = now ?? DateTime.now;

  final InsuredPersonRepository _insuredPeople;
  final CommercialInsuranceRepository _commercialInsurances;
  final SocialInsuranceRepository _socialInsurances;
  final TransactionRunner _runner;
  final IdGenerator _ids;
  final DateTime Function() _now;

  @override
  Future<String> save(SaveInsuredPersonCommand command) =>
      _runner.run(() async {
        final now = _now();
        final previous = command.id == null
            ? null
            : await _insuredPeople.find(command.id!);
        if (command.id != null && previous == null) {
          throw BusinessException(InsuranceErrorCode.insuredPersonNotFound);
        }
        final person = InsuredPerson(
          id: previous?.id ?? _ids.newId(),
          name: command.name.trim(),
          birthDate: DateTime(
            command.birthDate.year,
            command.birthDate.month,
            command.birthDate.day,
          ),
          relationship: command.relationship,
          gender: command.gender,
          note: _normalizeNote(command.note),
          avatarPreset: command.avatarPreset,
          createdAt: previous?.createdAt ?? now,
          updatedAt: now,
        );
        try {
          person.validate();
          final birthDate = DateTime(
            person.birthDate.year,
            person.birthDate.month,
            person.birthDate.day,
          );
          if (birthDate.isAfter(DateTime(now.year, now.month, now.day))) {
            throw ArgumentError('Birth date cannot be in the future.');
          }
        } on ArgumentError catch (error) {
          throw BusinessException(
            InsuranceErrorCode.invalidCommand,
            message: '请填写有效的被保险人姓名和出生日期。',
            cause: error,
          );
        }
        await _insuredPeople.save(person);
        return person.id;
      });

  String? _normalizeNote(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  Future<void> delete(String id) => _runner.run(() async {
    final person = await _insuredPeople.find(id);
    if (person == null) {
      throw BusinessException(InsuranceErrorCode.insuredPersonNotFound);
    }
    final referenced =
        await _commercialInsurances.existsForInsuredPerson(id) ||
        await _socialInsurances.existsForInsuredPerson(id);
    if (referenced) {
      throw BusinessException(InsuranceErrorCode.insuredPersonInUse);
    }
    await _insuredPeople.delete(id);
  });
}
