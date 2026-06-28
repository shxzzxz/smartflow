import '../../../core/money/money.dart';
import '../valobj/bill_enums.dart';
import '../valobj/bill_period.dart';
import '../valobj/bill_window.dart';

class Bill {
  const Bill({
    required this.id,
    required this.accountId,
    required this.period,
    required this.status,
    required this.items,
    this.window,
    this.createdAt,
  });

  final String id;
  final String accountId;
  final BillPeriod period;
  final BillWindow? window;
  final BillStatus status;
  final List<BillItem> items;
  final DateTime? createdAt;

  bool get hasPendingItems =>
      items.any((item) => item.status == BillItemStatus.pending);

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
        .where((item) => item.status == BillItemStatus.pending)
        .fold<int>(0, (sum, item) => sum + item.expectedPrincipal.minorUnits),
  );

  Bill copyWith({
    BillWindow? window,
    BillStatus? status,
    List<BillItem>? items,
  }) {
    return Bill(
      id: id,
      accountId: accountId,
      period: period,
      window: window ?? this.window,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt,
    );
  }
}

class BillItem {
  const BillItem({
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
  final String billId;
  final BillItemType itemType;
  final String? contractId;
  final String? scheduleId;
  final DateTime repaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final BillItemStatus status;
  final DateTime? createdAt;

  BillItem copyWith({
    String? id,
    String? billId,
    DateTime? repaymentDate,
    Money? expectedPrincipal,
    Money? expectedInterest,
    Money? expectedFee,
    BillItemStatus? status,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      itemType: itemType,
      contractId: contractId,
      scheduleId: scheduleId,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      expectedPrincipal: expectedPrincipal ?? this.expectedPrincipal,
      expectedInterest: expectedInterest ?? this.expectedInterest,
      expectedFee: expectedFee ?? this.expectedFee,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
