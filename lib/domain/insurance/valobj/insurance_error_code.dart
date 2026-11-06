import '../../../core/error/app_error_code.dart';

enum InsuranceErrorCode implements AppErrorCode {
  insuredPersonNotFound(
    code: 'insurance.insured_person.not_found',
    defaultMessage: '被保险人不存在。',
  ),
  insuredPersonInUse(
    code: 'insurance.insured_person.in_use',
    defaultMessage: '该被保险人仍被保险记录引用，无法删除。',
  ),
  commercialInsuranceNotFound(
    code: 'insurance.commercial.not_found',
    defaultMessage: '商业保险不存在。',
  ),
  socialInsuranceNotFound(
    code: 'insurance.social.not_found',
    defaultMessage: '社保记录不存在。',
  ),
  attachmentNotFound(
    code: 'insurance.attachment.not_found',
    defaultMessage: '保险附件不存在。',
  ),
  invalidCommand(
    code: 'insurance.invalid_command',
    defaultMessage: '保险信息不完整或不合法。',
  );

  const InsuranceErrorCode({required this.code, required this.defaultMessage});

  @override
  final String code;

  @override
  final String defaultMessage;
}
