import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/provider.dart';
import '../../../application/data_management/backup/backup_archive.dart';
import '../../../application/data_management/backup/backup_models.dart';
import '../../../application/data_management/backup/backup_service.dart';
import '../../shared/view_model/ui_action_outcome.dart';

final _logger = Logger('feature.profile.backup');

class BackupPageState {
  const BackupPageState({this.busy = false, this.message, this.error});

  final bool busy;
  final String? message;
  final UiError? error;

  BackupPageState copyWith({
    bool? busy,
    Object? message = _unset,
    Object? error = _unset,
  }) {
    return BackupPageState(
      busy: busy ?? this.busy,
      message: identical(message, _unset) ? this.message : message as String?,
      error: identical(error, _unset) ? this.error : error as UiError?,
    );
  }
}

const _unset = Object();

class BackupViewModel extends Notifier<BackupPageState> {
  late final BackupService _service;
  late final BackupArchivePort _archive;

  @override
  BackupPageState build() {
    _service = ref.watch(backupServiceProvider);
    _archive = ref.watch(backupArchivePortProvider);
    return const BackupPageState();
  }

  Future<UiActionOutcome<void>> export() async {
    if (state.busy) return const UiActionOutcome.failure(UiError.unknown());
    _set(state.copyWith(busy: true, message: null, error: null));
    try {
      final outcome = await _guard(
        'Backup export',
        () => _archive.export(_service),
      );
      if (outcome is UiActionSuccess<BackupManifest?> &&
          outcome.value != null) {
        _set(
          state.copyWith(
            message: '备份已导出，共 ${outcome.value!.files.length} 个文件。',
          ),
        );
      } else if (outcome is UiActionFailure<BackupManifest?>) {
        _set(state.copyWith(error: outcome.error));
      }
      return outcome.mapVoid();
    } finally {
      _set(state.copyWith(busy: false));
    }
  }

  Future<UiActionOutcome<BackupSelection?>> pickForRestore() async {
    if (state.busy) return const UiActionOutcome.success(null);
    _set(state.copyWith(busy: true, message: null, error: null));
    final outcome = await _guard('Pick backup', _archive.pickForRestore);
    if (outcome is UiActionFailure<BackupSelection?>) {
      _set(state.copyWith(error: outcome.error));
    }
    _set(state.copyWith(busy: false));
    return outcome;
  }

  Future<UiActionOutcome<BackupDiff>> compare(BackupSelection selection) async {
    final outcome = await _guard(
      'Compare backup',
      () => _archive.compare(_service, selection),
    );
    if (outcome is UiActionFailure<BackupDiff>) {
      _set(state.copyWith(error: outcome.error));
    }
    return outcome;
  }

  Future<UiActionOutcome<BackupDiff>> restore(BackupSelection selection) async {
    _set(state.copyWith(busy: true, message: null, error: null));
    try {
      final outcome = await _guard(
        'Restore backup',
        () => _archive.restore(_service, selection),
      );
      if (outcome is UiActionSuccess<BackupDiff>) {
        _set(state.copyWith(message: '恢复完成。${outcome.value.summary}'));
        ref.read(appDataRefreshProvider).refresh();
      } else if (outcome is UiActionFailure<BackupDiff>) {
        _set(state.copyWith(error: outcome.error));
      }
      return outcome;
    } finally {
      _set(state.copyWith(busy: false));
    }
  }

  void _set(BackupPageState next) => state = next;

  Future<UiActionOutcome<T>> _guard<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return UiActionOutcome.success(await action());
    } on BackupValidationException catch (error) {
      return UiActionOutcome.failure(
        UiError(code: 'backup.invalid', message: error.message),
      );
    } on FormatException catch (error) {
      return UiActionOutcome.failure(
        UiError(code: 'backup.invalid', message: error.message),
      );
    } on Exception catch (error, stackTrace) {
      _logger.severe('$operation failed unexpectedly.', error, stackTrace);
      return const UiActionOutcome.failure(UiError.unknown());
    }
  }
}

extension<T> on UiActionOutcome<T> {
  UiActionOutcome<void> mapVoid() {
    if (this is UiActionFailure<T>) {
      return UiActionOutcome.failure((this as UiActionFailure<T>).error);
    }
    return const UiActionOutcome.success(null);
  }
}

final backupViewModelProvider =
    NotifierProvider<BackupViewModel, BackupPageState>(BackupViewModel.new);
