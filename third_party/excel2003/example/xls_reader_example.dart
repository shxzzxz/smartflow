import 'dart:io';
import 'package:excel2003/excel2003.dart';

void main(List<String> args) {
  // Determine path from command-line args or use default
  final path = args.isNotEmpty ? args[0] : 'excel.xls';

  if (!File(path).existsSync()) {
    print('Error: XLS file not found at "${path}".');
    print('Usage: dart run example/xls_reader_example.dart <path-to-xls>');
    return;
  }

  // Open an XLS file
  final reader = XlsReader(path);
  reader.open();

  // Print workbook info
  print('Workbook opened successfully!');
  print('Number of sheets: ${reader.sheetCount}');
  print('Sheet names: ${reader.sheetNames}');
  print('');

  // Iterate through all sheets
  for (int i = 0; i < reader.sheetCount; i++) {
    final sheet = reader.sheet(i);
    print('=== Sheet ${i + 1}: "${sheet.name}" ===');
    print('Rows: ${sheet.rowCount}, Columns: ${sheet.colCount}');
    print(
      'Range: (${sheet.firstRow}, ${sheet.firstCol}) to (${sheet.lastRow}, ${sheet.lastCol})',
    );
    print('');

    // Print all non-empty cells
    for (int row = sheet.firstRow; row < sheet.lastRow; row++) {
      final rowValues = <String>[];
      for (int col = sheet.firstCol; col < sheet.lastCol; col++) {
        final value = sheet.cell(row, col);
        if (value != null) {
          rowValues.add('$value');
        } else {
          rowValues.add('');
        }
      }
      print('Row $row: ${rowValues.join('\t')}');
    }
    print('');
  }

  // Example: Convert first sheet to maps (using first row as headers)
  if (reader.sheetCount > 0) {
    final sheet = reader.sheet(0);
    final data = sheet.toMaps();
    print('=== Data as maps (first row as headers) ===');
    for (final row in data) {
      print(row);
    }
  }
}
