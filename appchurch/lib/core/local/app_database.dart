import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class SyncOperations extends Table {
  TextColumn get id => text()();
  TextColumn get scopeId => text()();
  TextColumn get operationType => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text().map(const JsonConverter())();
  TextColumn get dependsOn => text().nullable()();
  IntColumn get baseVersion => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class JsonConverter extends TypeConverter<Map<String, Object?>, String> {
  const JsonConverter();

  @override
  Map<String, Object?> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map).cast<String, Object?>();

  @override
  String toSql(Map<String, Object?> value) => jsonEncode(value);
}

@DriftDatabase(tables: [SyncOperations])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'tesouraria_local',
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationDocumentsDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  Stream<List<SyncOperation>> watchPendingOperations(String scopeId) {
    return (select(syncOperations)
          ..where(
            (row) => row.scopeId.equals(scopeId) & row.status.equals('PENDING'),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .watch();
  }

  Future<int> countPendingOperations(String scopeId) async {
    final rows =
        await (select(syncOperations)..where(
              (row) =>
                  row.scopeId.equals(scopeId) & row.status.equals('PENDING'),
            ))
            .get();
    return rows.length;
  }

  Future<List<SyncOperation>> pendingOperations(String scopeId) {
    return (select(syncOperations)
          ..where(
            (row) => row.scopeId.equals(scopeId) & row.status.equals('PENDING'),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
  }

  Future<void> enqueueOperation({
    required String id,
    required String scopeId,
    required String operationType,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
    String? dependsOn,
    int? baseVersion,
  }) async {
    final now = DateTime.now().toUtc();
    await into(syncOperations).insert(
      SyncOperationsCompanion.insert(
        id: id,
        scopeId: scopeId,
        operationType: operationType,
        entityType: entityType,
        entityId: entityId,
        payload: payload,
        dependsOn: Value(dependsOn),
        baseVersion: Value(baseVersion),
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> markOperationSyncing(String id) {
    return (update(syncOperations)..where((row) => row.id.equals(id))).write(
      SyncOperationsCompanion(
        status: const Value('SYNCING'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markOperationSynced(String id) {
    return (update(syncOperations)..where((row) => row.id.equals(id))).write(
      SyncOperationsCompanion(
        status: const Value('SYNCED'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markOperationFailed(String id, String error) {
    return transaction(() async {
      final operation = await (select(
        syncOperations,
      )..where((row) => row.id.equals(id))).getSingle();
      await (update(syncOperations)..where((row) => row.id.equals(id))).write(
        SyncOperationsCompanion(
          status: const Value('PENDING'),
          attemptCount: Value(operation.attemptCount + 1),
          lastError: Value(error),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  /// Envios recusados pela API, aguardando o usuário corrigir ou descartar.
  Future<List<SyncOperation>> rejectedOperations(String scopeId) {
    return (select(syncOperations)
          ..where(
            (row) =>
                row.scopeId.equals(scopeId) & row.status.equals('REJECTED'),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
  }

  /// Devolve à fila um envio recusado (ex.: depois de corrigir o ciclo).
  Future<void> retryOperation(String id) {
    return (update(syncOperations)..where((row) => row.id.equals(id))).write(
      SyncOperationsCompanion(
        status: const Value('PENDING'),
        lastError: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Descarta um envio recusado (fica no histórico local como DISCARDED).
  Future<void> discardOperation(String id) {
    return (update(syncOperations)..where((row) => row.id.equals(id))).write(
      SyncOperationsCompanion(
        status: const Value('DISCARDED'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Descarta da fila tudo o que ainda não foi enviado para [entityId]
  /// (desfazer lançamento/edição feito offline).
  Future<void> discardPendingFor(String scopeId, String entityId) {
    return (update(syncOperations)..where(
          (row) =>
              row.scopeId.equals(scopeId) &
              row.entityId.equals(entityId) &
              row.status.equals('PENDING'),
        ))
        .write(
          SyncOperationsCompanion(
            status: const Value('DISCARDED'),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  /// Quantas gravações ainda aguardam envio.
  Future<int> countPendingWrites(String scopeId, String entityType) async {
    final rows =
        await (select(syncOperations)..where(
              (row) =>
                  row.scopeId.equals(scopeId) &
                  row.entityType.equals(entityType) &
                  row.status.equals('PENDING'),
            ))
            .get();
    return rows.length;
  }

  /// Devolve à fila operações interrompidas (app fechado durante o envio).
  Future<void> resetInterruptedOperations() {
    return (update(syncOperations)
          ..where((row) => row.status.equals('SYNCING')))
        .write(const SyncOperationsCompanion(status: Value('PENDING')));
  }

  /// Operação recusada pela API (ex.: dados inválidos); não será reenviada.
  Future<void> markOperationRejected(String id, String error) {
    return (update(syncOperations)..where((row) => row.id.equals(id))).write(
      SyncOperationsCompanion(
        status: const Value('REJECTED'),
        lastError: Value(error),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 1) await m.createTable(syncOperations);
    },
  );
}
