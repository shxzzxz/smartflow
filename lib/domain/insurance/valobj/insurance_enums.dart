enum CommercialInsuranceCategory {
  medical('医疗'),
  criticalIllness('重疾'),
  accident('意外'),
  life('寿险'),
  other('其他');

  const CommercialInsuranceCategory(this.label);

  final String label;
}

enum PremiumFrequency {
  oneTime('一次性'),
  monthly('月缴'),
  quarterly('季缴'),
  semiAnnual('半年缴'),
  annual('年缴'),
  other('其他');

  const PremiumFrequency(this.label);

  final String label;
}

enum ResponsibilityKind {
  medical('医疗'),
  criticalIllness('重疾'),
  accident('意外'),
  life('寿险'),
  disability('伤残'),
  other('其他'),
  custom('自定义');

  const ResponsibilityKind(this.label);

  final String label;

  String get controlledName => label;
}

enum SocialParticipantType {
  employee('职工'),
  resident('居民');

  const SocialParticipantType(this.label);

  final String label;
}

enum MemberRelationship {
  self('本人'),
  spouse('配偶'),
  child('子女'),
  parent('父母'),
  other('其他');

  const MemberRelationship(this.label);

  final String label;
}

enum MemberGender {
  male('男'),
  female('女'),
  unknown('未知');

  const MemberGender(this.label);

  final String label;
}

enum MemberAvatarPreset {
  blue('蓝色'),
  green('绿色'),
  orange('橙色'),
  pink('粉色'),
  purple('紫色'),
  teal('青色');

  const MemberAvatarPreset(this.label);

  final String label;
}

enum InsuranceCoverageStatus {
  notStarted('未开始'),
  active('保障中'),
  ended('已结束'),
  lifetime('终身');

  const InsuranceCoverageStatus(this.label);

  final String label;
}

enum InsuranceSourceType {
  commercial('商业保险'),
  socialMedical('社保医保'),
  socialPension('社保养老');

  const InsuranceSourceType(this.label);

  final String label;
}
