import '../../../core/money/money.dart';
import '../../../core/error/app_exception.dart';
import '../valobj/bill_enums.dart';
import '../valobj/bill_period.dart';
import '../valobj/bill_window.dart';
import '../valobj/credit_error_code.dart';
import '../service/settlement/settlement_judgement_service.dart';

class BillAllocationApplicationResult {
  const BillAllocationApplicationResult({required this.scheduleItemStatuses});

  final Map<String, BillItemStatus> scheduleItemStatuses;
}

class Bill {
  static const _settlement = SettlementJudgementService();

  Bill({
    required this.id,
    required this.accountId,
    required this.period,
    required BillStatus status,
    required List<BillItem> items,
    this.window,
    this.createdAt,
  }) : _status = status,
       _items = List.of(items);

  final String id;
  final String accountId;
  final BillPeriod period;
  BillWindow? window;
  BillStatus _status;
  List<BillItem> _items;
  final DateTime? createdAt;

  BillStatus get status => _status;

  List<BillItem> get items => List.unmodifiable(_items);

  bool get hasPendingItems =>
      items.any((item) => item.status == BillItemStatus.pending);

  bool get hasOutstandingItems => items.any(
    (item) =>
        item.status == BillItemStatus.pending ||
        item.status == BillItemStatus.partiallyPaid,
  );

  Money get expectedPrincipal => Money(
    minorUnits: items.fold<int>(
      0,
      (sum, item) => sum + item.expectedPrincipal.minorUnits,
    ),
  );

  Money get expectedInterest => Money(
    minorUnits: items.fold<int>(
      0,
      (sum, item) => sum + item.expectedInterest.minorUnits,
    ),
  );

  Money get expectedFee => Money(
    minorUnits: items.fold<int>(
      0,
      (sum, item) => sum + item.expectedFee.minorUnits,
    ),
  );

  Money get pendingPrincipal => Money(
    minorUnits: items
        .where(
          (item) =>
              item.status == BillItemStatus.pending ||
              item.status == BillItemStatus.partiallyPaid,
        )
        .fold<int>(0, (sum, item) => sum + item.expectedPrincipal.minorUnits),
  );

  void alignLifecycle({BillWindow? window, required BillStatus status}) {
    if (window != null) this.window = window;
    _status = status;
  }

  void refreshOpenProjection({
    required BillWindow window,
    required List<BillItem> sourceItems,
  }) {
    _ensureOpen();
    this.window = window;
    _status = BillStatus.open;
    _items = List.of(sourceItems);
  }

  void freezeAsBilled({
    BillWindow? window,
    required List<BillItem> sourceItems,
  }) {
    if (window != null) this.window = window;
    _items = List.of(sourceItems);
    _status = _projectClosedStatus(_items);
  }

  void synchronizeBilledItems(List<BillItem> sourceItems) {
    if (_status == BillStatus.open) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }
    _items = List.of(sourceItems);
    _status = _projectClosedStatus(_items);
  }

  BillAllocationApplicationResult applyAllocations(
    Map<String, ({int principalMinor, bool hasAllocation})> allocationsByItemId,
  ) {
    final scheduleItemStatuses = <String, BillItemStatus>{};
    final itemIds = _items.map((item) => item.id).toSet();
    for (final itemId in allocationsByItemId.keys) {
      if (!itemIds.contains(itemId)) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
    }

    for (final item in _items) {
      final allocation = allocationsByItemId[item.id];
      if (allocation == null) continue;
      item._markStatus(
        _settlement.judgeBillItem(
          expectedPrincipalMinor: item.expectedPrincipal.minorUnits,
          allocatedPrincipalMinor: allocation.principalMinor,
          hasAllocation: allocation.hasAllocation,
        ),
      );
      if (item.scheduleId != null) {
        scheduleItemStatuses[item.scheduleId!] = item.status;
      }
    }
    _status = _projectStatus(_status, _items);
    return BillAllocationApplicationResult(
      scheduleItemStatuses: scheduleItemStatuses,
    );
  }

  void recalculateStatusFromItems() {
    _status = _projectStatus(_status, _items);
  }

  void _ensureOpen() {
    if (_status != BillStatus.open) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }
  }

  static BillStatus _projectStatus(BillStatus current, List<BillItem> items) {
    return _settlement.projectBillStatus(
      current,
      items.map((item) => item.status),
    );
  }

  static BillStatus _projectClosedStatus(List<BillItem> items) {
    return _settlement.projectBillStatus(
      BillStatus.billed,
      items.map((item) => item.status),
    );
  }
}

class BillItem {
  BillItem({
    required this.id,
    required this.billId,
    required this.itemType,
    required this.repaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.status,
    this.contractId,
    this.scheduleId,
    this.createdAt,
  });

  final String id;
  String billId;
  final BillItemType itemType;
  final String? contractId;
  final String? scheduleId;
  DateTime repaymentDate;
  Money expectedPrincipal;
  Money expectedInterest;
  Money expectedFee;
  BillItemStatus status;
  final DateTime? createdAt;

  void synchronizeProjection({
    String? billId,
    DateTime? repaymentDate,
    Money? expectedPrincipal,
    Money? expectedInterest,
    Money? expectedFee,
    BillItemStatus? status,
  }) {
    if (billId != null) this.billId = billId;
    if (repaymentDate != null) this.repaymentDate = repaymentDate;
    if (expectedPrincipal != null) this.expectedPrincipal = expectedPrincipal;
    if (expectedInterest != null) this.expectedInterest = expectedInterest;
    if (expectedFee != null) this.expectedFee = expectedFee;
    if (status != null) this.status = status;
  }

  void moveToBill(String nextBillId, {required DateTime repaymentDate}) {
    billId = nextBillId;
    this.repaymentDate = repaymentDate;
  }

  void _markStatus(BillItemStatus nextStatus) {
    status = nextStatus;
  }
}
