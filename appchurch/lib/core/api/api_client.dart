import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../supabase_config.dart';
import '../local/app_database.dart';
import 'api_cache.dart';

/// Tipo das operações da fila offline que são reenviadas para a API.
const apiRequestEntity = 'api_request';

/// Resultado de uma gravação: enviada agora ou guardada para sincronizar.
enum SendResult { sent, queued }

/// Acesso à API da tesouraria. Toda regra financeira fica no backend;
/// o app apenas envia o token do usuário e exibe as respostas.
///
/// Offline-first:
/// - consultas (`get`) guardam a última resposta e, sem conexão, usam essa cópia;
/// - gravações (`send`) sem conexão entram na fila local (`sync_operations`)
///   e são reenviadas pelo `SyncService` quando a API volta a responder;
/// - **modo offline**: depois de uma falha de conexão, consultas respondem na
///   hora com a cópia do aparelho e gravações vão direto para a fila, sem
///   esperar a API. Um teste leve (`/health`) roda em segundo plano e, quando
///   a API responde, o app volta ao modo online e sincroniza.
class ApiClient {
  ApiClient({
    required Future<String?> Function() accessToken,
    String baseUrl = apiBaseUrl,
    this.congregationId = defaultCongregationId,
    ApiCache? cache,
    this.database,
    Dio? dio,
    this.probeInterval = const Duration(seconds: 15),
  }) : _accessToken = accessToken,
       _cache = cache ?? FileApiCache(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: '$baseUrl/',
               // Curto: sem API, cai rápido para os dados do aparelho.
               connectTimeout: const Duration(seconds: 4),
               receiveTimeout: const Duration(seconds: 20),
             ),
           );

  final Future<String?> Function() _accessToken;
  final ApiCache _cache;
  final Dio _dio;
  final AppDatabase? database;
  final String congregationId;

  /// De quanto em quanto tempo testar a API enquanto estiver offline.
  final Duration probeInterval;
  Timer? _probeTimer;
  Future<bool>? _probing;

  /// `true` quando a última tentativa de falar com a API falhou por conexão.
  final ValueNotifier<bool> offline = ValueNotifier(false);

  /// Avisado sempre que a API responde, para disparar a sincronização.
  final ValueNotifier<int> reachable = ValueNotifier(0);

  Future<Object?> get(String path, {Map<String, Object?>? query}) async {
    final key = '$path?${jsonEncode(query ?? const {})}';
    if (offline.value) {
      // Modo offline: responde na hora com a cópia do aparelho e testa a
      // API em segundo plano (sem fazer a tela esperar).
      final cached = await _cache.read(key);
      if (cached != null) {
        unawaited(checkConnection());
        return cached;
      }
    }
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        options: await _options(),
      );
      _markOnline();
      await _cache.write(key, response.data);
      return response.data;
    } on DioException catch (error) {
      if (!isConnectionError(error)) rethrow;
      _markOffline();
      final cached = await _cache.read(key);
      if (cached == null) rethrow;
      return cached;
    }
  }

  /// Envia direto para a API, sem fila (usado também pelo `SyncService`).
  Future<Object?> post(String path, {Object? data}) async {
    final response = await _dio.post<Object?>(
      path,
      data: data,
      options: await _options(),
    );
    _markOnline();
    return response.data;
  }

  /// Grava na API ou, sem conexão, guarda na fila offline.
  /// O corpo deve levar um `id` gerado no app para o reenvio ser idempotente.
  Future<SendResult> send(String path, Map<String, Object?> body) async {
    // Modo offline: grava direto na fila, sem esperar a API.
    if (offline.value && database != null) return _enqueue(path, body);
    try {
      await post(path, data: body);
      return SendResult.sent;
    } on DioException catch (error) {
      if (!isConnectionError(error) || database == null) rethrow;
      _markOffline();
      return _enqueue(path, body);
    }
  }

  Future<SendResult> _enqueue(String path, Map<String, Object?> body) async {
    await database!.enqueueOperation(
      id: const Uuid().v4(),
      scopeId: congregationId,
      operationType: 'POST',
      entityType: apiRequestEntity,
      entityId: (body['id'] as String?) ?? const Uuid().v4(),
      payload: {'path': path, 'body': body},
    );
    return SendResult.queued;
  }

  /// Testa se a API responde (chamada leve). Volta ao modo online quando
  /// responde; chamadas simultâneas compartilham o mesmo teste.
  Future<bool> checkConnection() => _probing ??= _probe().whenComplete(() {
    _probing = null;
  });

  Future<bool> _probe() async {
    try {
      await _dio.get<Object?>(
        'health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      _markOnline();
      return true;
    } on DioException catch (error) {
      if (isConnectionError(error)) {
        _markOffline();
        return false;
      }
      // Respondeu (mesmo com erro): a API está no ar.
      _markOnline();
      return true;
    }
  }

  /// Libera o teste periódico (ao sair do app).
  void dispose() => _probeTimer?.cancel();

  /// Quantas gravações feitas offline ainda aguardam envio.
  Future<int> pendingWrites() async =>
      await database?.countPendingWrites(congregationId, apiRequestEntity) ?? 0;

  void _markOnline() {
    _probeTimer?.cancel();
    _probeTimer = null;
    offline.value = false;
    reachable.value++;
  }

  void _markOffline() {
    offline.value = true;
    scheduleProbe();
  }

  /// Agenda o teste periódico da API enquanto estiver offline.
  @protected
  void scheduleProbe() {
    _probeTimer ??= Timer.periodic(probeInterval, (_) => checkConnection());
  }

  Future<Options> _options() async {
    final token = await _accessToken();
    return Options(
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }
}

/// Sem resposta da API (sem rede, API desligada) ou API sem acesso ao banco
/// (502/503/504): consultas usam o cache e gravações ficam na fila.
bool isConnectionError(DioException error) {
  final status = error.response?.statusCode;
  if (status != null) return status == 502 || status == 503 || status == 504;
  return error.type != DioExceptionType.cancel &&
      error.type != DioExceptionType.badCertificate;
}

/// Converte erros de rede/API em mensagens para o usuário.
String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (data is Map && data['message'] is List) {
      return (data['message'] as List).join('\n');
    }
    if (isConnectionError(error)) {
      return 'Sem conexão com a API e ainda não há dados salvos neste aparelho. '
          'Conecte-se à internet e tente novamente.';
    }
  }
  if (error is StateError) return error.message;
  return 'Ocorreu um erro inesperado. Tente novamente.';
}
