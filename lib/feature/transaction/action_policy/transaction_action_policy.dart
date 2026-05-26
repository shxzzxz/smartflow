import '../../../core/result/result.dart';

/// 通用 UI 与业务域之间的"槽集"。
///
/// 详见 docs/08.2 通用UI与业务域接入协议.md。
abstract interface class TransactionActionPolicy {
  Future<Result<void>> delete();

  String editRoutePath();

  Future<Result<void>> changeSettlementAccount(int newAccountId);

  Future<Result<void>> changeOccurredAt(DateTime newTime);

  Future<Result<void>> changeNote(String? newNote);

  EditPermission canEdit(EditableField field);

  /// 可选的横幅提示文本：编排层用来标注该笔交易的归属与受限范围。
  /// 默认 policy 返回 null（无横幅）。
  String? displayBanner();
}

enum EditableField { settlementAccount, occurredAt, note, amount }

sealed class EditPermission {
  const EditPermission();

  const factory EditPermission.allowed() = EditPermissionAllowed;

  const factory EditPermission.denied({String? reason}) = EditPermissionDenied;

  bool get isAllowed => this is EditPermissionAllowed;

  String? get deniedReason =>
      this is EditPermissionDenied
          ? (this as EditPermissionDenied).reason
          : null;
}

final class EditPermissionAllowed extends EditPermission {
  const EditPermissionAllowed();
}

final class EditPermissionDenied extends EditPermission {
  const EditPermissionDenied({this.reason});

  final String? reason;
}
