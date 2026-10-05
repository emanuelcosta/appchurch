import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../local/app_database.dart';

/// Reenvia para a API as gravações feitas sem conexão, na ordem em que
/// foram feitas. Roda ao abrir o app, quando a internet volta e sempre que a
/// API volta a responder.
class SyncService {
  SyncService({
    required AppDatabase database,
    required ApiClient api,
    Connectivity? connectivity,
  }) : _database = database,
       _api = api,
       _connectivity = connectivity;

  final AppDatabase _database;
  final ApiClient _api;
  final Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _running = false;

  /// Quantidade de gravações aguardando envio.
  final ValueNotifier<int> pending = ValueNotifier(0);

  /// Quantidade de envios recusados pela API (precisam de atenção).
  final ValueNotifier<int> rejected = ValueNotifier(0);

  void start() {
    _api.reachable.addListener(synchronize);
    try {
      _connectivitySubscription = (_connectivity ?? Connectivity())
          .onConnectivityChanged
          .listen((results) {
            // Rede voltou: testa a API agora; se responder, o aviso de
            // "API de volta" dispara a sincronização.
            if (!results.contains(ConnectivityResult.none)) {
              _api.checkConnection();
            }
          });
    } catch (_) {
      // Sem plugin de conectividade (ex.: testes): segue sincronizando
      // quando a API responder.
    }
    _database.resetInterruptedOperations().then((_) => synchronize());
  }

  void dispose() {
    _api.reachable.removeListener(synchronize);
    _connectivitySubscription?.cancel();
  }

  Future<void> synchronize() async {
    if (_running) return;
    _running = true;
    try {
      final operations = (await _database.pendingOperations(
        _api.congregationId,
      )).where((operation) => operation.entityType == apiRequestEntity);
      for (final operation in operations) {
        final path = operation.payload['path'] as String?;
        if (path == null) continue;
        await _database.markOperationSyncing(operation.id);
        try {
          await _api.post(path, data: operation.payload['body']);
          await _database.markOperationSynced(operation.id);
        } on DioException catch (error) {
          // Sem conexão, banco fora do ar ou sessão expirada: tenta depois.
          if (isConnectionError(error) || error.response?.statusCode == 401) {
            await _database.markOperationFailed(
              operation.id,
              describeApiError(error),
            );
            break;
          }
          // Recusada pela API (dados inválidos): não adianta reenviar.
          await _database.markOperationRejected(
            operation.id,
            describeApiError(error),
          );
        }
      }
    } finally {
      _running = false;
      await _refreshPending();
    }
  }

  Future<void> _refreshPending() async {
    final operations = await _database.pendingOperations(_api.congregationId);
    pending.value = operations
        .where((operation) => operation.entityType == apiRequestEntity)
        .length;
    final refused = await _database.rejectedOperations(_api.congregationId);
    rejected.value = refused
        .where((operation) => operation.entityType == apiRequestEntity)
        .length;
  }

  /// Envios recusados, para a tela de correção.
  Future<List<SyncOperation>> rejectedOperations() async =>
      (await _database.rejectedOperations(_api.congregationId))
          .where((operation) => operation.entityType == apiRequestEntity)
          .toList();

  /// Recoloca um envio recusado na fila e tenta enviar de novo.
  Future<void> retry(String operationId) async {
    await _database.retryOperation(operationId);
    await synchronize();
  }

  /// Descarta um envio recusado (o lançamento não será enviado).
  Future<void> discard(String operationId) async {
    await _database.discardOperation(operationId);
    await _refreshPending();
  }
}
