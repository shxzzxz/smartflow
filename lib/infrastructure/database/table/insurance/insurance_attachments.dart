import 'package:drift/drift.dart';

@DataClassName('InsuranceAttachmentRow')
class InsuranceAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get commercialInsuranceId =>
      text().named('commercial_insurance_id')();
  TextColumn get fileName => text().named('file_name')();
  TextColumn get storageKey => text().named('storage_key')();
  TextColumn get mimeType => text().named('mime_type')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (length(trim(file_name)) > 0)",
    "CHECK (length(trim(storage_key)) > 0)",
    "CHECK (length(trim(mime_type)) > 0)",
  ];
}
