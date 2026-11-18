import '../../../application/insurance/insurance_command_api.dart';

List<String> responsibilityNameSuggestions(ResponsibilityKind kind) {
  return switch (kind) {
    ResponsibilityKind.medical => const [
      '一般医疗',
      '重疾医疗',
      '门急诊医疗',
      '意外医疗',
      '质子重离子医疗',
    ],
    ResponsibilityKind.diseaseBenefit => const ['重大疾病', '中症', '轻症'],
    ResponsibilityKind.death => const ['身故', '意外身故', '疾病身故', '猝死'],
    ResponsibilityKind.disability => const ['意外伤残', '全残'],
    ResponsibilityKind.other => const ['住院津贴', '保费豁免'],
  };
}

List<String> responsibilityPointNameSuggestions(ResponsibilityKind kind) {
  return [
    '保障额度',
    '给付条件',
    '等待期',
    '赔付方式',
    ...switch (kind) {
      ResponsibilityKind.medical => const [
        '免赔额',
        '赔付比例',
        '医院范围',
        '住院医疗',
        '特殊门诊',
        '门诊手术',
        '住院前后门急诊',
        '院外药械',
        '院外特种药品',
        '临床急需进口药械',
        '重疾康复费用',
      ],
      ResponsibilityKind.diseaseBenefit => const [
        '疾病种类',
        '赔付比例',
        '赔付次数',
        '间隔期',
      ],
      ResponsibilityKind.death => const ['赔付金额'],
      ResponsibilityKind.disability => const ['伤残等级', '赔付比例', '赔付金额'],
      ResponsibilityKind.other => const [
        '赔付金额',
        '赔付次数',
        '津贴标准',
        '给付天数',
        '豁免条件',
        '豁免范围',
      ],
    },
  ];
}
