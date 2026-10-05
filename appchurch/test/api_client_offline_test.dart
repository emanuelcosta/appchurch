import 'dart:convert';
import 'dart:typed_data';

import 'package:appchurch/core/api/api_cache.dart';
import 'package:appchurch/core/api/api_client.dart';
import 'package:appchurch/core/local/app_database.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Rede" simulada: responde JSON ou falha como API fora do ar, contando as
/// chamadas por caminho.
class FakeNetwork implements HttpClientAdapter {
  bool online = true;
  final calls = <String, int>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    calls[path] = (calls[path] ?? 0) + 1;
    if (!online) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'path': path}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase database;
  late FakeNetwork network;
  late ApiClient api;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    network = FakeNetwork();
    api = ApiClient(
      accessToken: () async => 'token',
      cache: MemoryApiCache(),
      database: database,
      baseUrl: 'http://api.test',
      dio: Dio(BaseOptions(baseUrl: 'http://api.test/'))
        ..httpClientAdapter = network,
      probeInterval: const Duration(hours: 1),
    );
  });

  tearDown(() async {
    api.dispose();
    await database.close();
  });

  test(
    'offline: depois da 1ª falha, responde do aparelho sem esperar a API',
    () async {
      await api.get('finance/ledger'); // online: guarda a cópia
      network.online = false;

      await api.get('finance/ledger'); // falha uma vez e entra em modo offline
      expect(api.offline.value, isTrue);
      expect(network.calls['finance/ledger'], 2);

      // Próximas consultas: direto da cópia, sem chamar a API (só o teste leve).
      final data = await api.get('finance/ledger');
      await api.get('finance/ledger');
      expect(data, {'path': 'finance/ledger'});
      expect(network.calls['finance/ledger'], 2);
    },
  );

  test('offline: gravação vai direto para a fila, sem chamar a API', () async {
    network.online = false;
    await api.get('finance/dashboard').catchError((_) => null);
    expect(api.offline.value, isTrue);

    final result = await api.send('finance/revenues', {'id': 'r1'});
    expect(result, SendResult.queued);
    expect(network.calls['finance/revenues'], isNull);
    expect(await api.pendingWrites(), 1);
  });

  test('quando a API volta, o teste leve sai do modo offline', () async {
    network.online = false;
    await api.get('finance/dashboard').catchError((_) => null);
    expect(api.offline.value, isTrue);
    final before = api.reachable.value;

    network.online = true;
    expect(await api.checkConnection(), isTrue);
    expect(api.offline.value, isFalse);
    expect(network.calls['health'], 1);
    // Aviso de "API de volta" dispara a sincronização da fila.
    expect(api.reachable.value, before + 1);
  });
}
