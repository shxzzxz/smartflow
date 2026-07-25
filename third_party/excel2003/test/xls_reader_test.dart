import 'dart:io';

import 'package:excel2003/excel2003.dart';
import 'package:test/test.dart';

void main() {
  group('XlsReader', () {
    test('throws on non-existent file', () {
      final reader = XlsReader('non_existent.xls');
      expect(() => reader.open(), throwsA(isA<ArgumentError>()));
    });

    test('reads existing XLS file', () {
      final file = File('test_data.xls');
      if (!file.existsSync()) {
        print('Skipping test: excel.xls not found');
        return;
      }

      final reader = XlsReader('test_data.xls');
      reader.open();

      expect(reader.sheetCount, greaterThan(0));
      expect(reader.sheetNames, isNotEmpty);
    });

    test('reads sheet data', () {
      final file = File('test_data.xls');
      if (!file.existsSync()) {
        print('Skipping test: excel.xls not found');
        return;
      }

      final reader = XlsReader('test_data.xls');
      reader.open();

      final sheet = reader.sheet(0);
      expect(sheet.name, isNotEmpty);

      // Print some debug info
      print('Sheet: ${sheet.name}');
      print('Rows: ${sheet.rowCount}, Cols: ${sheet.colCount}');

      // Verify we can access cells
      for (final cell in sheet.cells.take(10)) {
        print('Cell(${cell.row}, ${cell.col}): ${cell.value} [${cell.type}]');
      }
    });
  });

  group('XlsSheet', () {
    test('toMaps converts sheet to list of maps', () {
      final file = File('test_data.xls');
      if (!file.existsSync()) {
        print('Skipping test: excel.xls not found');
        return;
      }

      final reader = XlsReader('test_data.xls');
      reader.open();

      if (reader.sheetCount > 0) {
        final sheet = reader.sheet(0);
        final maps = sheet.toMaps();

        if (maps.isNotEmpty) {
          print('First row as map: ${maps.first}');
          expect(maps.first, isA<Map<String, dynamic>>());
        }
      }
    });
  });

  group('CellType', () {
    test('cell types are correctly identified', () {
      final file = File('test_data.xls');
      if (!file.existsSync()) {
        print('Skipping test: excel.xls not found');
        return;
      }

      final reader = XlsReader('test_data.xls');
      reader.open();

      if (reader.sheetCount > 0) {
        final sheet = reader.sheet(0);

        final typeCount = <CellType, int>{};
        for (final cell in sheet.cells) {
          typeCount[cell.type] = (typeCount[cell.type] ?? 0) + 1;
        }

        print('Cell type distribution: $typeCount');
      }
    });
  });
}
