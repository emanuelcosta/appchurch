import 'package:appchurch/core/api/api_cache.dart';
import 'package:appchurch/core/api/api_client.dart';
import 'package:dio/dio.dart';

/// API falsa: responde com dados fixos por caminho, ou simula falta de conexão.
class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.responses = const {},
    this.connected = true,
    super.database,
  }) : super(accessToken: () async => 'token', cache: MemoryApiCache());

  final Map<String, Object?> responses;
  bool connected;
  final posts = <String, Object?>{};

  /// Como o cache real: o que já foi lido continua disponível offline.
  final _seen = <String, Object?>{};

  DioException _offlineError(String path) => DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.connectionError,
  );

  @override
  Future<Object?> get(String path, {Map<String, Object?>? query}) async {
    // Como numa chamada de rede real, responde de forma assíncrona.
    await Future<void>.delayed(Duration.zero);
    if (!connected) {
      offline.value = true;
      if (_seen.containsKey(path)) return _seen[path];
      throw _offlineError(path);
    }
    offline.value = false;
    return _seen[path] = responses[path];
  }

  @override
  Future<Object?> post(String path, {Object? data}) async {
    await Future<void>.delayed(Duration.zero);
    if (!connected) throw _offlineError(path);
    posts[path] = data;
    return data;
  }
}
