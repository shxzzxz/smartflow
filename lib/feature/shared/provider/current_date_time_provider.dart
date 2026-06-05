import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_date_time_provider.g.dart';

@riverpod
DateTime currentDateTime(Ref ref) {
  return DateTime.now();
}
