/// Leitura tolerante de JSON vindo da API: campos ausentes ou com tipo
/// inesperado viram valores neutros em vez de derrubar a tela.
Map<String, dynamic> asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : <Map<String, dynamic>>[];

double asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

bool asBool(Object? value) => value == true;

String? asString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

DateTime? asDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
