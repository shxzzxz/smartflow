import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/insurance/entity/social_insurance.dart';
import '../../../../domain/insurance/port/insured_person_repository.dart';
import '../../../../domain/insurance/port/social_insurance_repository.dart';
import '../../../../domain/insurance/valobj/insurance_enums.dart';
import '../../../../domain/insurance/valobj/insurance_error_code.dart';
import '../../../shared/transaction_runner.dart';
import 'social_insurance_command.dart';

abstract interface class SocialInsuranceAppService {
  Future<String> save(SaveSocialInsuranceCommand command);
  Future<void> delete(String id);
}

class SocialInsuranceAppServiceImpl implements SocialInsuranceAppService {
  SocialInsuranceAppServiceImpl({
    required SocialInsuranceRepository insurances,
    required InsuredPersonRepository insuredPeople,
    required TransactionRunner runner,
    required IdGenerator ids,
    DateTime Function()? now,
  }) : _insurances = insurances,
       _insuredPeople = insuredPeople,
       _runner = runner,
       _ids = ids,
       _now = now ?? DateTime.now;

  final SocialInsuranceRepository _insurances;
  final InsuredPersonRepository _insuredPeople;
  final TransactionRunner _runner;
  final IdGenerator _ids;
  final DateTime Function() _now;

  @override
  Future<String> save(SaveSocialInsuranceCommand command) {
    return _runner.run(() async {
      final now = _now();
      final previous = command.id == null
          ? null
          : await _insurances.find(command.id!);
      if (command.id != null && previous == null) {
        throw BusinessException(InsuranceErrorCode.socialInsuranceNotFound);
      }
      _ensureHistoryStable(
        previous: previous,
        region: command.region,
        insuranceType: command.insuranceType,
        participantType: command.participantType,
      );
      await _ensurePerson(command.insuredPersonId);
      final insurance = SocialInsurance(
        id: previous?.id ?? _ids.newId(),
        insuredPersonId: command.insuredPersonId,
        region: command.region,
        insuranceType: command.insuranceType,
        participantType: command.participantType,
        contributionRecords: command.contributionRecords,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      );
      _validate(insurance.validate);
      await _insurances.save(insurance);
      return insurance.id;
    });
  }

  @override
  Future<void> delete(String id) {
    return _runner.run(() async {
      if (await _insurances.find(id) == null) {
        throw BusinessException(InsuranceErrorCode.socialInsuranceNotFound);
      }
      await _insurances.delete(id);
    });
  }

  Future<void> _ensurePerson(String insuredPersonId) async {
    if (await _insuredPeople.find(insuredPersonId) == null) {
      throw BusinessException(InsuranceErrorCode.insuredPersonNotFound);
    }
  }

  void _ensureHistoryStable({
    required SocialInsurance? previous,
    required String region,
    required SocialInsuranceType insuranceType,
    required SocialParticipantType participantType,
  }) {
    if (previous == null) return;
    final normalizedRegion = region.trim();
    final changed =
        previous.region != normalizedRegion ||
        previous.insuranceType != insuranceType ||
        previous.participantType != participantType;
    if (!changed) return;
    throw BusinessException(
      InsuranceErrorCode.invalidCommand,
      message: '社保类型、参保地区或参保类型发生变化时，请新建社保记录以保留历史。',
    );
  }

  void _validate(void Function() validate) {
    try {
      validate();
    } on ArgumentError catch (error) {
      throw BusinessException(
        InsuranceErrorCode.invalidCommand,
        message: '请检查参保信息，并确保同一记录的缴费年月不重复。',
        cause: error,
      );
    }
  }
}
