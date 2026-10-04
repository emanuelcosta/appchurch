import 'package:appchurch/core/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('queues an operation once using its id', () async {
    await database.enqueueOperation(
      id: 'operation-1',
      scopeId: 'congregation-1',
      operationType: 'CREATE',
      entityType: 'financial_entry',
      entityId: 'entry-1',
      payload: {'amount': 10},
    );
    await database.enqueueOperation(
      id: 'operation-1',
      scopeId: 'congregation-1',
      operationType: 'CREATE',
      entityType: 'financial_entry',
      entityId: 'entry-1',
      payload: {'amount': 10},
    );

    final operations = await database
        .watchPendingOperations('congregation-1')
        .first;
    expect(operations, hasLength(1));
    expect(operations.single.payload['amount'], 10);
  });
}
