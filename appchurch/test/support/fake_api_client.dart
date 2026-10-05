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

  /// Caminhos que a API recusa (400) com a mensagem informada.
  final rejections = <String, String>{};

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
    // Como a API real: responder dispara a sincronização da fila.
    reachable.value++;
    return _seen[path] = responses[path];
  }

  /// Nos testes não há teste periódico: o estado muda via [connected].
  @override
  void scheduleProbe() {}

  @override
  Future<bool> checkConnection() async {
    offline.value = !connected;
    if (connected) reachable.value++;
    return connected;
  }

  @override
  Future<Object?> post(String path, {Object? data}) async {
    await Future<void>.delayed(Duration.zero);
    if (!connected) throw _offlineError(path);
    final rejection = rejections[path];
    if (rejection != null) {
      final options = RequestOptions(path: path);
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: {'message': rejection},
        ),
      );
    }
    posts[path] = data;
    return data;
  }
}
