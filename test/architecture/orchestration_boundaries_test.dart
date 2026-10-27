import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ledger does not depend on orchestration concepts', () {
    final ledgerFiles = Directory('lib/domain/ledger')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in ledgerFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('domain/orchestration')),
        reason: '${file.path} imports orchestration.',
      );
      expect(
        source,
        isNot(contains('AdvanceScenario')),
        reason: '${file.path} still owns advance scenarios.',
      );
      expect(
        source,
        isNot(contains('AdvanceTrackingMode')),
        reason: '${file.path} still owns advance tracking modes.',
      );
    }
  });

  test(
    'orchestration domain does not depend on application or infrastructure',
    () {
      final orchestrationFiles = Directory('lib/domain/orchestration')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in orchestrationFiles) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('application/')));
        expect(source, isNot(contains('infrastructure/')));
      }
    },
  );
}
