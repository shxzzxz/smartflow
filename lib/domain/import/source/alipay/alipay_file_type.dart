import '../../import_models.dart';

enum AlipayFileType {
  bill(key: 'bill', label: '支付宝交易明细');

  const AlipayFileType({required this.key, required this.label});

  final String key;
  final String label;

  ImportSourceFileType get descriptor =>
      ImportSourceFileType(source: ImportSource.alipay, key: key, label: label);
}
