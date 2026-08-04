import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/import_file_reader.dart';
import 'package:smartflow/infrastructure/import/xls_file_reader.dart';

void main() {
  test('reports damaged XLS bytes as a decode failure', () {
    const reader = XlsFileReader();

    expect(
      () => reader.read(
        ImportFilePayload(name: '账单.xls', bytes: Uint8List.fromList([1, 2, 3])),
      ),
      throwsA(
        isA<ImportFileReadException>().having(
          (error) => error.failure,
          'failure',
          ImportFileReadFailure.decodeFailed,
        ),
      ),
    );
  });
}
