import '../import_models.dart';

enum YimuFileType {
  bill(key: 'bill', label: '账单'),
  transfer(key: 'transfer', label: '转账'),
  debt(key: 'debt', label: '债务');

  const YimuFileType({required this.key, required this.label});

  final String key;
  final String label;

  ImportSourceFileType get descriptor =>
      ImportSourceFileType(source: ImportSource.yimu, key: key, label: label);
}
