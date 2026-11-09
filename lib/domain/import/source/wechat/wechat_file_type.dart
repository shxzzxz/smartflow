import '../../import_models.dart';

enum WechatFileType {
  bill(key: 'bill', label: '微信支付账单');

  const WechatFileType({required this.key, required this.label});

  final String key;
  final String label;

  ImportSourceFileType get descriptor =>
      ImportSourceFileType(source: ImportSource.wechat, key: key, label: label);
}
