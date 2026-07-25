import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/infrastructure/import/yimu_excel2003_workbook_reader.dart';

void main() {
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
