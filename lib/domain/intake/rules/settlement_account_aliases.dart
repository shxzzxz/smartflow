import 'recognition_rule.dart';
import 'recognition_rule_target.dart';

/// Name equivalence only; aliases never bind or create ledger accounts.
String? matchSettlementAccountAlias(
  String? paymentMethod,
  List<RecognitionRuleTarget> targets, {
  RecognitionRuleSource? source,
}) {
  final alias = _aliasGroup(paymentMethod, source);
  if (alias == null) return null;
  for (final target in targets) {
    if (target.kind == RecognitionRuleKind.account &&
        _aliasGroup(target.name, source) == alias) {
      return target.id;
    }
  }
  return null;
}

int? _aliasGroup(String? value, RecognitionRuleSource? source) {
  final name = normalizeRecognitionText(value);
  var longest = 0;
  int? match;
  for (var index = 0; index < _groups.length; index++) {
    for (final alias in _groups[index]) {
      if (alias == '余额' && source != RecognitionRuleSource.alipay) continue;
      if (alias.length > longest && name.contains(alias)) {
        longest = alias.length;
        match = index;
      }
    }
  }
  return match;
}

// Product names precede broad platform names when equally specific.
const _groups = <List<String>>[
  ['支付宝余额宝', '天弘余额宝', '余额宝'],
  ['微信零钱通', '零钱通'],
  ['支付宝花呗', '花呗'],
  ['微信分付', '分付'],
  ['京东白条', '白条'],
  ['美团月付', '月付'],
  ['微信零钱', '微信余额', '微信', '零钱'],
  ['支付宝余额', '支付宝', '余额'],
  ['现金支付', '现金'],
  ['中国邮政储蓄银行', '邮政储蓄银行', '邮政储蓄', '邮储银行', '邮储', 'psbc'],
  ['中国工商银行', '工商银行', '工商', '工行', 'icbc'],
  ['中国建设银行', '建设银行', '建行', 'ccb'],
  ['中国农业银行', '农业银行', '农行', 'abc'],
  ['中国银行', '中行', 'boc'],
  ['招商银行', '招商', '招行', 'cmb'],
  ['交通银行', '交行', 'bocom'],
  ['中信银行', '中信', 'citic'],
  ['中国光大银行', '光大银行', '光大', 'ceb'],
  ['中国民生银行', '民生银行', '民生', 'cmbc'],
  ['平安银行', '平安', 'pab'],
  ['兴业银行', '兴业', 'cib'],
  ['浦东发展银行', '浦发银行', '浦发', 'spdb'],
  ['华夏银行', '华夏', 'hxb'],
  ['广发银行', '广发', 'cgb'],
  ['浙商银行', '浙商', 'czbank'],
  ['北京银行'],
  ['上海银行'],
  ['宁波银行'],
  ['江苏银行'],
];
