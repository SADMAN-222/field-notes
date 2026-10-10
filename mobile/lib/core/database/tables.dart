import 'package:drift/drift.dart';

@DataClassName('Customer')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get contactInformation => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Site')
class Sites extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get siteName => text()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FieldNote')
class FieldNotes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get siteId => text().references(Sites, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncOutboxEntry')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'customer', 'site', 'note', 'photo'
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // 'CREATE', 'UPDATE', 'DELETE'
  TextColumn get payload => text().nullable()(); // JSON representation of the entity
  IntColumn get expectedVersion => integer().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get lastError => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('PENDING'))(); // PENDING, FAILED
}

@DataClassName('SyncMetadataEntry')
class SyncMetadata extends Table {
  TextColumn get id => text()(); // 'cursor'
  TextColumn get value => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

