import 'package:logging/logging.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/insurance/entity/commercial_insurance.dart';
import '../../../../domain/insurance/port/commercial_insurance_repository.dart';
import '../../../../domain/insurance/port/insured_person_repository.dart';
import '../../../../domain/insurance/valobj/coverage_responsibility.dart';
import '../../../../domain/insurance/valobj/insurance_attachment.dart';
import '../../../../domain/insurance/valobj/insurance_error_code.dart';
import '../../../shared/transaction_runner.dart';
import '../../attachment/port/insurance_attachment_storage.dart';
import 'commercial_insurance_command.dart';

final _logger = Logger('application.insurance.commercial');

abstract interface class CommercialInsuranceAppService {
  Future<String> save(SaveCommercialInsuranceCommand command);
  Future<void> delete(String id);
  Future<int> addAttachments(String insuranceId);
  Future<void> deleteAttachment({
    required String insuranceId,
    required String attachmentId,
  });
  Future<void> openAttachment({
    required String insuranceId,
    required String attachmentId,
  });
}

class CommercialInsuranceAppServiceImpl
    implements CommercialInsuranceAppService {
  CommercialInsuranceAppServiceImpl({
    required CommercialInsuranceRepository insurances,
    required InsuredPersonRepository insuredPeople,
    required InsuranceAttachmentStorage attachmentStorage,
    required TransactionRunner runner,
    required IdGenerator ids,
    DateTime Function()? now,
  }) : _insurances = insurances,
       _insuredPeople = insuredPeople,
       _attachmentStorage = attachmentStorage,
       _runner = runner,
       _ids = ids,
       _now = now ?? DateTime.now;

  final CommercialInsuranceRepository _insurances;
  final InsuredPersonRepository _insuredPeople;
  final InsuranceAttachmentStorage _attachmentStorage;
  final TransactionRunner _runner;
  final IdGenerator _ids;
  final DateTime Function() _now;

  @override
  Future<String> save(SaveCommercialInsuranceCommand command) {
    return _runner.run(() async {
      final now = _now();
      final previous = command.id == null
          ? null
          : await _insurances.find(command.id!);
      if (command.id != null && previous == null) {
        throw BusinessException(InsuranceErrorCode.commercialInsuranceNotFound);
      }

      final personIds = command.insuredPersonIds.toSet().toList();
      for (final personId in personIds) {
        if (await _insuredPeople.find(personId) == null) {
          throw BusinessException(InsuranceErrorCode.insuredPersonNotFound);
        }
      }

      final responsibilities = command.responsibilities == null
          ? previous?.responsibilities ?? const <CoverageResponsibility>[]
          : _buildResponsibilities(
              command.responsibilities!,
              previous: previous,
            );

      final insurance = CommercialInsurance(
        id: previous?.id ?? _ids.newId(),
        name: command.name,
        insurerName: command.insurerName,
        category: command.category,
        productForm: _nullIfBlank(command.productForm),
        coverageTerm: command.coverageTerm,
        coverageAmount:
            command.coverageAmount == null || command.coverageAmount!.isEmpty
            ? null
            : command.coverageAmount,
        premiumPlan: command.premiumPlan,
        insuredPersonIds: personIds,
        responsibilities: responsibilities,
        attachments: previous?.attachments ?? const [],
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      );
      try {
        insurance.validate();
      } on ArgumentError catch (error) {
        throw BusinessException(
          InsuranceErrorCode.invalidCommand,
          message: '请检查商业保险的必填项、保障期间和关联成员。',
          cause: error,
        );
      }
      await _insurances.save(insurance);
      return insurance.id;
    });
  }

  @override
  Future<void> delete(String id) {
    return _runner.run(() async {
      final insurance = await _require(id);
      await _insurances.delete(id);
      for (final attachment in insurance.attachments) {
        await _deleteFileBestEffort(attachment.storageKey);
      }
    });
  }

  @override
  Future<int> addAttachments(String insuranceId) async {
    await _require(insuranceId);
    final drafts = await _attachmentStorage.pickAndStore(
      commercialInsuranceId: insuranceId,
    );
    if (drafts.isEmpty) return 0;
    final createdAt = _now();
    final added = [
      for (final draft in drafts)
        InsuranceAttachment(
          id: _ids.newId(),
          fileName: draft.fileName,
          storageKey: draft.storageKey,
          mimeType: draft.mimeType,
          createdAt: createdAt,
        ),
    ];
    try {
      await _runner.run(() async {
        final latest = await _require(insuranceId);
        final updated = _copyWithAttachments(
          latest,
          attachments: [...latest.attachments, ...added],
          updatedAt: _now(),
        );
        try {
          updated.validate();
        } on ArgumentError catch (error) {
          throw BusinessException(
            InsuranceErrorCode.invalidCommand,
            cause: error,
          );
        }
        await _insurances.save(updated);
      });
    } catch (error, stackTrace) {
      for (final draft in drafts) {
        try {
          await _attachmentStorage.delete(draft.storageKey);
        } catch (cleanupError, cleanupStackTrace) {
          _logger.warning(
            'Failed to clean up uncommitted insurance attachment.',
            cleanupError,
            cleanupStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return added.length;
  }

  @override
  Future<void> deleteAttachment({
    required String insuranceId,
    required String attachmentId,
  }) async {
    late InsuranceAttachment removed;
    await _runner.run(() async {
      final insurance = await _require(insuranceId);
      final match = insurance.attachments
          .where((item) => item.id == attachmentId)
          .firstOrNull;
      if (match == null) {
        throw BusinessException(InsuranceErrorCode.attachmentNotFound);
      }
      removed = match;
      await _insurances.save(
        _copyWithAttachments(
          insurance,
          attachments: [
            for (final item in insurance.attachments)
              if (item.id != attachmentId) item,
          ],
          updatedAt: _now(),
        ),
      );
    });
    await _deleteFileBestEffort(removed.storageKey);
  }

  @override
  Future<void> openAttachment({
    required String insuranceId,
    required String attachmentId,
  }) async {
    final insurance = await _require(insuranceId);
    final attachment = insurance.attachments
        .where((item) => item.id == attachmentId)
        .firstOrNull;
    if (attachment == null) {
      throw BusinessException(InsuranceErrorCode.attachmentNotFound);
    }
    await _attachmentStorage.open(attachment.storageKey);
  }

  Future<CommercialInsurance> _require(String id) async {
    final insurance = await _insurances.find(id);
    if (insurance == null) {
      throw BusinessException(InsuranceErrorCode.commercialInsuranceNotFound);
    }
    return insurance;
  }

  List<CoverageResponsibility> _buildResponsibilities(
    List<InsuranceResponsibilityInput> inputs, {
    required CommercialInsurance? previous,
  }) {
    final previousResponsibilityIds = <String>{
      for (final item in previous?.responsibilities ?? const []) item.id,
    };
    final previousPointIds = <String>{
      for (final item in previous?.responsibilities ?? const [])
        for (final point in item.points) point.id,
    };
    return [
      for (
        var responsibilityIndex = 0;
        responsibilityIndex < inputs.length;
        responsibilityIndex++
      )
        _buildResponsibility(
          inputs[responsibilityIndex],
          order: responsibilityIndex,
          previousResponsibilityIds: previousResponsibilityIds,
          previousPointIds: previousPointIds,
        ),
    ];
  }

  CoverageResponsibility _buildResponsibility(
    InsuranceResponsibilityInput input, {
    required int order,
    required Set<String> previousResponsibilityIds,
    required Set<String> previousPointIds,
  }) {
    final responsibilityId =
        input.id != null && previousResponsibilityIds.contains(input.id)
        ? input.id!
        : _ids.newId();
    final points = [
      for (var pointIndex = 0; pointIndex < input.points.length; pointIndex++)
        ResponsibilityPoint(
          id:
              input.points[pointIndex].id != null &&
                  previousPointIds.contains(input.points[pointIndex].id)
              ? input.points[pointIndex].id!
              : _ids.newId(),
          label: input.points[pointIndex].label.trim(),
          value: input.points[pointIndex].value.trim(),
          order: pointIndex,
        ),
    ];
    return CoverageResponsibility(
      id: responsibilityId,
      kind: input.kind,
      name: input.name,
      points: points,
      order: order,
    );
  }

  CommercialInsurance _copyWithAttachments(
    CommercialInsurance insurance, {
    required List<InsuranceAttachment> attachments,
    required DateTime updatedAt,
  }) {
    return CommercialInsurance(
      id: insurance.id,
      name: insurance.name,
      insurerName: insurance.insurerName,
      category: insurance.category,
      productForm: insurance.productForm,
      coverageTerm: insurance.coverageTerm,
      coverageAmount: insurance.coverageAmount,
      premiumPlan: insurance.premiumPlan,
      insuredPersonIds: insurance.insuredPersonIds,
      responsibilities: insurance.responsibilities,
      attachments: attachments,
      createdAt: insurance.createdAt,
      updatedAt: updatedAt,
    );
  }

  Future<void> _deleteFileBestEffort(String storageKey) async {
    try {
      await _attachmentStorage.delete(storageKey);
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to delete insurance attachment file.',
        error,
        stackTrace,
      );
    }
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
