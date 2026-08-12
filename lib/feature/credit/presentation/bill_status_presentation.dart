import '../../../application/credit/credit_query_api.dart';

String billStatusLabel(BillStatus status) {
  return switch (status) {
    BillStatus.open => '累积中',
    BillStatus.billed => '已出账',
    BillStatus.settled => '已了结',
  };
}
