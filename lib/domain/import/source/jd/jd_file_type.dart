import '../../import_models.dart';

enum JdFileType {
  bill(key: 'bill', label: '京东商城交易流水');

  const JdFileType({required this.key, required this.label});

  final String key;
  final String label;

  ImportSourceFileType get descriptor =>
      ImportSourceFileType(source: ImportSource.jd, key: key, label: label);
}
