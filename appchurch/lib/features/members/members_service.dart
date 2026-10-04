import '../../core/api/api_client.dart';
import '../../core/utils/json.dart';
import 'member.dart';

const _membersPath = 'finance/members';

class MembersService {
  const MembersService(this._api);

  final ApiClient _api;

  /// Membros da API (ou do cache offline) mais os cadastros feitos offline
  /// que ainda aguardam sincronização.
  Future<List<Member>> list() async {
    final data = await _api.get(
      _membersPath,
      query: {'congregationId': _api.congregationId},
    );
    if (data is! List) {
      throw StateError('A API retornou uma resposta inválida para membros.');
    }
    final members = asMapList(data).map(Member.fromJson).toList();
    final known = members.map((member) => member.id).toSet();
    final pending = await _pendingMembers();
    return [
      ...members,
      ...pending.where((member) => !known.contains(member.id)),
    ]..sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  }

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
