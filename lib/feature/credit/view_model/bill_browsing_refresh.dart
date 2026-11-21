import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import '../../../core/error/app_exception.dart';
import '../../shared/view_model/action_guard.dart';

/// One background projection refresh per browsing session. Rebuilding a query
/// after the write must not start another refresh or replace cached content.
class BillBrowsingRefresh {
  var _started = false;
  static final _logger = Logger('feature.credit.bill_refresh');

  void reset() => _started = false;

  void schedule(
    Ref ref, {
    required Future<void> Function() refresh,
    required FutureOr<void> Function() onRefreshed,
  }) {
    if (_started) return;
    _started = true;
    unawaited(
      Future<void>(() async {
        if (!ref.mounted) return;
        try {
          await refresh();
          if (ref.mounted) await onRefreshed();
        } on AppException catch (error, stackTrace) {
          _started = false;
          logUiActionException(
            _logger,
            'Bill background refresh',
            error,
            stackTrace,
          );
        } on Exception catch (error, stackTrace) {
          _started = false;
          _logger.severe('Bill background refresh failed.', error, stackTrace);
        }
      }),
    );
  }
}
