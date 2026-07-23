import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/infrastructure/import/yimu_excel2003_workbook_reader.dart';

void main() {
  final sampleDirectory = _sampleDirectoryOrNull();
  test(
    'decodes the three real anonymized Yimu BIFF8 workbooks',
    () {
      final directory = sampleDirectory!;
      final reader = const YimuExcel2003WorkbookReader();
      final expected = {
        '账单_0406193148.xls': '收支类型',
        '转账_0406193209.xls': '类型',
        '债务_0406193307.xls': '类型',
      };

      for (final entry in expected.entries) {
        final file = File(
          '${directory.path}${Platform.pathSeparator}${entry.key}',
        );
        final workbook = reader.read(
          ImportFilePayload(
            name: entry.key,
            bytes: Uint8List.fromList(file.readAsBytesSync()),
          ),
        );
        expect(workbook.sheets, isNotEmpty);
        expect(workbook.sheets.first.headers, contains(entry.value));
        expect(workbook.sheets.first.rows, isNotEmpty);
      }
    },
    skip:
        sampleDirectory == null
            ? 'Local anonymized Yimu samples are not available.'
            : false,
  );

  test('reports damaged XLS bytes as a decode failure', () {
    final reader = const YimuExcel2003WorkbookReader();

    expect(
      () => reader.read(
        ImportFilePayload(name: '账单.xls', bytes: Uint8List.fromList([1, 2, 3])),
      ),
      throwsA(isA<YimuWorkbookReadException>()),
    );
  });
}

Directory? _sampleDirectoryOrNull() {
  final local = Directory('demo/data/一木记账');
  if (local.existsSync()) return local;
  final worktreeSibling = Directory(
    '${Directory.current.parent.parent.path}${Platform.pathSeparator}'
    'demo${Platform.pathSeparator}data${Platform.pathSeparator}一木记账',
  );
  if (worktreeSibling.existsSync()) return worktreeSibling;
  return null;
}
