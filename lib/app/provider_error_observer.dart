import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final class AppProviderErrorObserver extends ProviderObserver {
  AppProviderErrorObserver({Logger? logger})
    : _logger = logger ?? Logger('app.provider');

  final Logger _logger;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.severe('Provider failed: ${context.provider}', error, stackTrace);
  }
}
