import 'package:go_router/go_router.dart';

import '../application/intake/intake_recognition_api.dart';

void openSharedPaymentImage(GoRouter router, SharedPaymentImage image) {
  final location = '/capture/${image.id}';
  final path = router.state.uri.path;
  if (path == '/capture' || path.startsWith('/capture/')) {
    router.pushReplacement(location);
  } else {
    router.push(location);
  }
}
