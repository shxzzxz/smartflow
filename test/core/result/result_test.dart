import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';

void main() {
  group('Result', () {
    test('reads success branch', () {
      const result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.when(success: (value) => value, failure: (_) => 0), 42);
    });

    test('reads failure branch', () {
      const result = Result<int>.failure(Failure(message: 'invalid'));

      expect(result.isFailure, isTrue);
      expect(
        result.when(
          success: (_) => 'ok',
          failure: (failure) => failure.message,
        ),
        'invalid',
      );
    });
  });
}
