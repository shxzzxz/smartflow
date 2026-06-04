import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';

part 'reimbursement_form_view_model.g.dart';

@riverpod
class ReimbursementReceiptFormViewModel
    extends _$ReimbursementReceiptFormViewModel {
  @override
  Future<ReimbursementReceiptFormState> build(
    String advanceTransactionId,
  ) async {
    final base = await _loadBase(ref, advanceTransactionId);
    if (base == null) {
      return ReimbursementReceiptFormState.notFound(accounts: const []);
    }
    if (base.receivableAccountId == null || base.outstanding == null) {
      return ReimbursementReceiptFormState.notEditable(accounts: base.accounts);
    }
    return ReimbursementReceiptFormState.loaded(
      accounts: base.accounts,
      outstanding: base.outstanding!,
      receivableAccountId: base.receivableAccountId!,
      receiveAccountId: base.accounts.isEmpty ? null : base.accounts.first.id,
      occurredAt: DateTime.now(),
    );
  }

  void setAmountText(String value) =>
      _update((state) => state.copyWith(amountText: value));

  void setNoteText(String value) =>
      _update((state) => state.copyWith(noteText: value));

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setReceiveAccountId(String? value) =>
      _update((state) => state.copyWith(receiveAccountId: value));

  Future<SubmitOutcome> submit() async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('报销到账表单尚未加载');
    }
    final amount = _parsePositiveMoney(current.amountText);
    if (amount == null) return _invalidCommand('请输入有效到账金额');
    final receiveAccountId = _selectedId(
      current.receiveAccountId,
      current.accounts,
    );
    if (receiveAccountId == null) return _invalidCommand('请选择到账账户');

    _update((state) => state.copyWith(submitting: true));
    try {
      await ref
          .read(transactionPostingAppServiceProvider)
          .createReimbursementReceipt(
            CreateReimbursementReceiptCommand(
              amount: amount,
              advanceTransactionId: advanceTransactionId,
              receivableAccountId: current.receivableAccountId!,
              receiveAccountId: receiveAccountId,
              occurredAt: current.occurredAt,
              note: trimToNull(current.noteText),
            ),
          );
      _invalidateAfterSubmit(ref, advanceTransactionId);
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _update(
    ReimbursementReceiptFormState Function(ReimbursementReceiptFormState)
    update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }
}

@riverpod
class ReimbursementCloseFormViewModel
    extends _$ReimbursementCloseFormViewModel {
  @override
  Future<ReimbursementCloseFormState> build(String advanceTransactionId) async {
    final base = await _loadBase(ref, advanceTransactionId);
    if (base == null) {
      return ReimbursementCloseFormState.notFound(accounts: const []);
    }
    if (base.receivableAccountId == null || base.outstanding == null) {
      return ReimbursementCloseFormState.notEditable(accounts: base.accounts);
    }
    return ReimbursementCloseFormState.loaded(
      accounts: base.accounts,
      outstanding: base.outstanding!,
      receivableAccountId: base.receivableAccountId!,
      amountText: base.outstanding!.format(),
      receiveAccountId: base.accounts.isEmpty ? null : base.accounts.first.id,
      occurredAt: DateTime.now(),
    );
  }

  void setAmountText(String value) =>
      _update((state) => state.copyWith(amountText: value));

  void setNoteText(String value) =>
      _update((state) => state.copyWith(noteText: value));

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setReceiveAccountId(String? value) =>
      _update((state) => state.copyWith(receiveAccountId: value));

  Future<SubmitOutcome> submit() async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('结束报销表单尚未加载');
    }
    final amount = Money.tryParse(current.amountText);
    if (amount == null || amount.minorUnits < 0) {
      return _invalidCommand('请输入有效实收金额');
    }
    final receiveAccountId =
        amount.minorUnits > 0
            ? _selectedId(current.receiveAccountId, current.accounts)
            : current.receivableAccountId;
    if (receiveAccountId == null) return _invalidCommand('请选择到账账户');

    _update((state) => state.copyWith(submitting: true));
    try {
      await ref
          .read(transactionPostingAppServiceProvider)
          .closeReimbursement(
            CloseReimbursementCommand(
              actualReceivedAmount: amount,
              advanceTransactionId: advanceTransactionId,
              receivableAccountId: current.receivableAccountId!,
              receiveAccountId: receiveAccountId,
              occurredAt: current.occurredAt,
              note: trimToNull(current.noteText),
            ),
          );
      _invalidateAfterSubmit(ref, advanceTransactionId);
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _update(
    ReimbursementCloseFormState Function(ReimbursementCloseFormState) update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }
}

enum ReimbursementFormStatus { loaded, notFound, notEditable }

class ReimbursementReceiptFormState extends _ReimbursementFormState {
  const ReimbursementReceiptFormState({
    required super.status,
    required super.accounts,
    required super.amountText,
    required super.noteText,
    required super.occurredAt,
    required super.submitting,
    super.outstanding,
    super.receivableAccountId,
    super.receiveAccountId,
  });

  factory ReimbursementReceiptFormState.loaded({
    required List<Account> accounts,
    required Money outstanding,
    required String receivableAccountId,
    required DateTime occurredAt,
    String? receiveAccountId,
  }) {
    return ReimbursementReceiptFormState(
      status: ReimbursementFormStatus.loaded,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId,
      amountText: '',
      noteText: '',
      occurredAt: occurredAt,
      submitting: false,
    );
  }

  factory ReimbursementReceiptFormState.notFound({
    required List<Account> accounts,
  }) {
    return ReimbursementReceiptFormState._empty(
      status: ReimbursementFormStatus.notFound,
      accounts: accounts,
    );
  }

  factory ReimbursementReceiptFormState.notEditable({
    required List<Account> accounts,
  }) {
    return ReimbursementReceiptFormState._empty(
      status: ReimbursementFormStatus.notEditable,
      accounts: accounts,
    );
  }

  factory ReimbursementReceiptFormState._empty({
    required ReimbursementFormStatus status,
    required List<Account> accounts,
  }) {
    return ReimbursementReceiptFormState(
      status: status,
      accounts: accounts,
      amountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      submitting: false,
    );
  }

  ReimbursementReceiptFormState copyWith({
    String? amountText,
    String? noteText,
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    bool? submitting,
  }) {
    return ReimbursementReceiptFormState(
      status: status,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId:
          receiveAccountId == _sentinel
              ? this.receiveAccountId
              : receiveAccountId as String?,
      amountText: amountText ?? this.amountText,
      noteText: noteText ?? this.noteText,
      occurredAt: occurredAt ?? this.occurredAt,
      submitting: submitting ?? this.submitting,
    );
  }
}

class ReimbursementCloseFormState extends _ReimbursementFormState {
  const ReimbursementCloseFormState({
    required super.status,
    required super.accounts,
    required super.amountText,
    required super.noteText,
    required super.occurredAt,
    required super.submitting,
    super.outstanding,
    super.receivableAccountId,
    super.receiveAccountId,
  });

  factory ReimbursementCloseFormState.loaded({
    required List<Account> accounts,
    required Money outstanding,
    required String receivableAccountId,
    required String amountText,
    required DateTime occurredAt,
    String? receiveAccountId,
  }) {
    return ReimbursementCloseFormState(
      status: ReimbursementFormStatus.loaded,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId,
      amountText: amountText,
      noteText: '',
      occurredAt: occurredAt,
      submitting: false,
    );
  }

  factory ReimbursementCloseFormState.notFound({
    required List<Account> accounts,
  }) {
    return ReimbursementCloseFormState._empty(
      status: ReimbursementFormStatus.notFound,
      accounts: accounts,
    );
  }

  factory ReimbursementCloseFormState.notEditable({
    required List<Account> accounts,
  }) {
    return ReimbursementCloseFormState._empty(
      status: ReimbursementFormStatus.notEditable,
      accounts: accounts,
    );
  }

  factory ReimbursementCloseFormState._empty({
    required ReimbursementFormStatus status,
    required List<Account> accounts,
  }) {
    return ReimbursementCloseFormState(
      status: status,
      accounts: accounts,
      amountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      submitting: false,
    );
  }

  Money? get gap {
    final outstanding = this.outstanding;
    final actual = Money.tryParse(amountText);
    if (outstanding == null || actual == null) return null;
    return actual - outstanding;
  }

  ReimbursementCloseFormState copyWith({
    String? amountText,
    String? noteText,
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    bool? submitting,
  }) {
    return ReimbursementCloseFormState(
      status: status,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId:
          receiveAccountId == _sentinel
              ? this.receiveAccountId
              : receiveAccountId as String?,
      amountText: amountText ?? this.amountText,
      noteText: noteText ?? this.noteText,
      occurredAt: occurredAt ?? this.occurredAt,
      submitting: submitting ?? this.submitting,
    );
  }
}

abstract class _ReimbursementFormState {
  const _ReimbursementFormState({
    required this.status,
    required this.accounts,
    required this.amountText,
    required this.noteText,
    required this.occurredAt,
    required this.submitting,
    this.outstanding,
    this.receivableAccountId,
    this.receiveAccountId,
  });

  final ReimbursementFormStatus status;
  final List<Account> accounts;
  final Money? outstanding;
  final String? receivableAccountId;
  final String? receiveAccountId;
  final String amountText;
  final String noteText;
  final DateTime occurredAt;
  final bool submitting;

  bool get isLoaded => status == ReimbursementFormStatus.loaded;
}

class _ReimbursementBase {
  const _ReimbursementBase({
    required this.accounts,
    this.outstanding,
    this.receivableAccountId,
  });

  final List<Account> accounts;
  final Money? outstanding;
  final String? receivableAccountId;
}

Future<_ReimbursementBase?> _loadBase(
  Ref ref,
  String advanceTransactionId,
) async {
  final accounts = await ref.watch(
    accountsForUsageProvider(AccountUsage.settlement).future,
  );
  final accountsById = await ref.watch(accountsByIdProvider.future);
  final detail = await ref.watch(
    transactionDetailProvider(advanceTransactionId).future,
  );
  if (detail == null) return null;
  return _ReimbursementBase(
    accounts: accounts,
    outstanding: detail.reimbursementSummary?.outstanding,
    receivableAccountId: reimbursementReceivableAccountId(detail, accountsById),
  );
}

void _invalidateAfterSubmit(Ref ref, String advanceTransactionId) {
  ref.invalidate(transactionDetailProvider(advanceTransactionId));
  ref.invalidate(accountsByIdProvider);
  ref.invalidate(accountsForUsageProvider(AccountUsage.settlement));
}

SubmitOutcome _invalidCommand(String message) {
  return SubmitOutcome.failure(
    UiError(
      code: LedgerErrorCode.transactionInvalidCommand.code,
      message: message,
    ),
  );
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id != null && accounts.any((account) => account.id == id)) return id;
  return accounts.isEmpty ? null : accounts.first.id;
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits > 0 ? money : null;
}

const Object _sentinel = Object();
