import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/app/provider_error_observer.dart';

final _failingProvider = Provider<int>((ref) => throw StateError('provider'));

void main() {
  test('AppProviderErrorObserver logs provider failures', () {
    final logger = Logger.detached('test.provider');
    final records = <LogRecord>[];
    final subscription = logger.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    final container = ProviderContainer(
      observers: [AppProviderErrorObserver(logger: logger)],
    );
    addTearDown(container.dispose);

    expect(() => container.read(_failingProvider), throwsA(anything));

    expect(records, hasLength(1));
    expect(records.single.message, contains('Provider failed:'));
    expect(records.single.error, isA<StateError>());
  });
}
