import '../../core/api/api_client.dart';
import '../../core/utils/json.dart';

const roleLabels = {
  'ADMIN': 'Administrador',
  'TREASURER': 'Tesoureiro',
  'ASSISTANT': 'Auxiliar',
  'REVIEWER': 'Revisor',
  'SECRETARY': 'Secretário(a)',
  'VIEWER': 'Visualizador',
  'AUDITOR': 'Auditor',
};

class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.memberships,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    fullName: asString(json['fullName']) ?? 'Usuário',
    email: asString(json['email']),
    memberships: asMapList(json['memberships'])
        .map(
          (item) => (
            congregation: asString(item['congregationName']) ?? 'Congregação',
            role: roleLabels[item['role']] ?? asString(item['role']) ?? '-',
          ),
        )
        .toList(),
  );

  final String fullName;
  final String? email;
  final List<({String congregation, String role})> memberships;

  /// Congregação principal do usuário (a primeira vinculada).
  String? get congregationName =>
      memberships.isEmpty ? null : memberships.first.congregation;
}

class ProfileService {
  const ProfileService(this._api);

  final ApiClient _api;

  /// Usuário logado (funciona offline com a última cópia salva).
  Future<UserProfile> load() async {
    final data = await _api.get('me');
    if (data is! Map) {
      throw StateError('A API retornou uma resposta inválida para o perfil.');
    }
    return UserProfile.fromJson(Map<String, dynamic>.from(data));
  }
}
