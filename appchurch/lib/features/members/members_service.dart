import '../../core/api/api_client.dart';
import '../../core/utils/json.dart';
import 'member.dart';

const _membersPath = 'finance/members';

class MembersService {
  const MembersService(this._api);

  final ApiClient _api;

  /// Membros da API (ou do cache offline) com os cadastros e edições feitos
  /// offline que ainda aguardam sincronização (a versão pendente prevalece).
  Future<List<Member>> list() async {
    final data = await _api.get(
      _membersPath,
      query: {'congregationId': _api.congregationId},
    );
    if (data is! List) {
      throw StateError('A API retornou uma resposta inválida para membros.');
    }
    final byId = {
      for (final member in asMapList(data).map(Member.fromJson))
        member.id: member,
    };
    // Na ordem da fila: a última alteração de cada membro vale.
    for (final member in await _pendingMembers()) {
      byId[member.id] = member;
    }
    return byId.values.toList()..sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  }

  /// Cadastra ou, com o mesmo id, edita. Sem conexão, vai para a fila.
  Future<SendResult> create(NewMember member) =>
      _api.send(_membersPath, member.toJson(_api.congregationId));

  Future<List<Member>> _pendingMembers() async {
    final database = _api.database;
    if (database == null) return [];
    final operations = await database.pendingOperations(_api.congregationId);
    return operations
        .where(
          (operation) =>
              operation.entityType == apiRequestEntity &&
              operation.payload['path'] == _membersPath,
        )
        .map((operation) => Member.pending(asMap(operation.payload['body'])))
        .toList();
  }
}
