import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Guarda a última resposta de cada consulta à API para uso offline.
abstract class ApiCache {
  Future<Object?> read(String key);
  Future<void> write(String key, Object? value);
}

/// Cache em arquivos JSON na pasta de documentos do app.
class FileApiCache implements ApiCache {
  Directory? _directory;

  Future<Directory> _dir() async {
    if (_directory != null) return _directory!;
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/api_cache');
    if (!directory.existsSync()) directory.createSync(recursive: true);
    return _directory = directory;
  }

  File _file(Directory dir, String key) =>
      File('${dir.path}/${base64Url.encode(utf8.encode(key))}.json');

  @override
  Future<Object?> read(String key) async {
    try {
      final file = _file(await _dir(), key);
      if (!file.existsSync()) return null;
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? value) async {
    try {
      await _file(await _dir(), key).writeAsString(jsonEncode(value));
    } catch (_) {
      // Falha ao gravar o cache não deve interromper o uso do app.
    }
  }
}

/// Cache em memória, usado nos testes.
class MemoryApiCache implements ApiCache {
  final _values = <String, Object?>{};

  @override
  Future<Object?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, Object? value) async => _values[key] = value;
}
