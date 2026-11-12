import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/business_icon_provider.dart';
import '../../../app/user_business_icon_providers.dart';
import '../../../application/data_management/icons/command/user_business_icon_app_service.dart';
import '../../../application/data_management/icons/query/user_business_icon_query_service.dart';
import '../../../application/data_management/icons/user_business_icon_models.dart';
import '../../../core/error/app_exception.dart';
import '../../shared/view_model/ui_action_outcome.dart';

final _logger = Logger('feature.icon_management');

class IconManagementPageState {
  const IconManagementPageState({
    this.icons = const [],
    this.loading = true,
    this.busy = false,
    this.loadError,
  });

  final List<UserBusinessIconEntry> icons;
  final bool loading;
  final bool busy;
  final UiError? loadError;

  IconManagementPageState copyWith({
    List<UserBusinessIconEntry>? icons,
    bool? loading,
    bool? busy,
    Object? loadError = _unset,
  }) {
    return IconManagementPageState(
      icons: icons ?? this.icons,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      loadError: identical(loadError, _unset)
          ? this.loadError
          : loadError as UiError?,
    );
  }
}

const _unset = Object();

class IconManagementViewModel extends Notifier<IconManagementPageState> {
  late final UserBusinessIconAppService _commands;
  late final UserBusinessIconQueryService _queries;

  @override
  IconManagementPageState build() {
    _commands = ref.watch(userBusinessIconAppServiceProvider);
    _queries = ref.watch(userBusinessIconQueryServiceProvider);
    return const IconManagementPageState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, loadError: null);
    try {
      final icons = await _queries.list();
      state = state.copyWith(icons: icons, loading: false, loadError: null);
    } on AppException catch (error, stackTrace) {
      _logger.warning(
        'Failed to load user icons [${error.code}].',
        error.cause ?? error,
        error.stackTrace ?? stackTrace,
      );
      state = state.copyWith(
        loading: false,
        loadError: UiError.fromException(error),
      );
    } on Exception catch (error, stackTrace) {
      _logger.severe('Failed to load user icons.', error, stackTrace);
      state = state.copyWith(
        loading: false,
        loadError: const UiError.unknown(),
      );
    }
  }

  Future<UiActionOutcome<UserBusinessIconRecord?>> upload(
    UserBusinessIconType type,
  ) async {
    if (state.busy) return const UiActionOutcome.failure(_busyError);
    state = state.copyWith(busy: true);
    try {
      final icon = await _commands.upload(type);
      if (icon == null) return const UiActionOutcome.success(null);
      await _reloadAfterMutation();
      return UiActionOutcome.success(icon);
    } on AppException catch (error, stackTrace) {
      _logger.warning(
        'Failed to upload user icon [${error.code}].',
        error.cause ?? error,
        error.stackTrace ?? stackTrace,
      );
      return UiActionOutcome.failure(UiError.fromException(error));
    } on Exception catch (error, stackTrace) {
      _logger.severe('Failed to upload user icon.', error, stackTrace);
      return const UiActionOutcome.failure(UiError.unknown());
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<UiActionOutcome<void>> delete(UserBusinessIconRecord icon) async {
    if (state.busy) return const UiActionOutcome.failure(_busyError);
    state = state.copyWith(busy: true);
    try {
      await _commands.delete(icon);
      await _reloadAfterMutation();
      return const UiActionOutcome.success(null);
    } on AppException catch (error, stackTrace) {
      _logger.warning(
        'Failed to delete user icon [${error.code}].',
        error.cause ?? error,
        error.stackTrace ?? stackTrace,
      );
      return UiActionOutcome.failure(UiError.fromException(error));
    } on Exception catch (error, stackTrace) {
      _logger.severe('Failed to delete user icon.', error, stackTrace);
      return const UiActionOutcome.failure(UiError.unknown());
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> _reloadAfterMutation() async {
    try {
      final icons = await _queries.list();
      state = state.copyWith(icons: icons, loading: false, loadError: null);
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'User icon changed but the management list could not be refreshed.',
        error,
        stackTrace,
      );
    }
    try {
      await ref.read(businessIconRegistryProvider.notifier).reload();
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'User icon changed but the icon registry could not be refreshed.',
        error,
        stackTrace,
      );
    }
  }
}

const _busyError = UiError(
  code: 'feature.icon_management.busy',
  message: '正在处理上一项操作，请稍候。',
);

final iconManagementViewModelProvider =
    NotifierProvider<IconManagementViewModel, IconManagementPageState>(
      IconManagementViewModel.new,
    );
