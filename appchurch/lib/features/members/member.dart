import '../../core/utils/json.dart';

/// Ficha de membro (mesmas colunas da planilha membros.xlsx).
class Member {
  const Member({
    required this.id,
    required this.fullName,
    this.birthDate,
    this.rg,
    this.cpf,
    this.maritalStatus,
    this.motherName,
    this.fatherName,
    this.spouseName,
    this.address,
    this.nationality,
    this.birthplace,
    this.ministryRole,
    this.ministryRoleSince,
    this.holySpiritBaptism,
    this.holySpiritBaptismDate,
    this.education,
    this.childrenCount,
    this.phone,
    this.email,
    this.pendingSync = false,
  });

  /// Lido da API (colunas do banco em snake_case).
  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: asString(json['id']) ?? '',
    fullName: asString(json['full_name']) ?? 'Sem nome',
    birthDate: asDate(json['birth_date']),
    rg: asString(json['rg']),
    cpf: asString(json['cpf']),
    maritalStatus: asString(json['marital_status']),
    motherName: asString(json['mother_name']),
    fatherName: asString(json['father_name']),
    spouseName: asString(json['spouse_name']),
    address: asString(json['address']),
    nationality: asString(json['nationality']),
    birthplace: asString(json['birthplace']),
    ministryRole: asString(json['ministry_role']),
    ministryRoleSince: asDate(json['ministry_role_since']),
    holySpiritBaptism: json['holy_spirit_baptism'] is bool
        ? json['holy_spirit_baptism'] as bool
        : null,
    holySpiritBaptismDate: asDate(json['holy_spirit_baptism_date']),
    education: asString(json['education']),
    childrenCount: json['children_count'] is num
        ? (json['children_count'] as num).toInt()
        : null,
    phone: asString(json['phone']),
    email: asString(json['email']),
  );

  /// Cadastro feito offline, ainda na fila de sincronização.
  factory Member.pending(Map<String, dynamic> body) => Member(
    id: asString(body['id']) ?? '',
    fullName: asString(body['fullName']) ?? 'Sem nome',
    birthDate: asDate(body['birthDate']),
    rg: asString(body['rg']),
    cpf: asString(body['cpf']),
    maritalStatus: asString(body['maritalStatus']),
    motherName: asString(body['motherName']),
    fatherName: asString(body['fatherName']),
    spouseName: asString(body['spouseName']),
    address: asString(body['address']),
    nationality: asString(body['nationality']),
    birthplace: asString(body['birthplace']),
    ministryRole: asString(body['ministryRole']),
    ministryRoleSince: asDate(body['ministryRoleSince']),
    holySpiritBaptism: body['holySpiritBaptism'] is bool
        ? body['holySpiritBaptism'] as bool
        : null,
    holySpiritBaptismDate: asDate(body['holySpiritBaptismDate']),
    education: asString(body['education']),
    childrenCount: body['childrenCount'] is num
        ? (body['childrenCount'] as num).toInt()
        : null,
    phone: asString(body['phone']),
    email: asString(body['email']),
    pendingSync: true,
  );

  final String id;
  final String fullName;
  final DateTime? birthDate;
  final String? rg;
  final String? cpf;
  final String? maritalStatus;
  final String? motherName;
  final String? fatherName;
  final String? spouseName;
  final String? address;
  final String? nationality;
  final String? birthplace;
  final String? ministryRole;
  final DateTime? ministryRoleSince;
  final bool? holySpiritBaptism;
  final DateTime? holySpiritBaptismDate;
  final String? education;
  final int? childrenCount;
  final String? phone;
  final String? email;
  final bool pendingSync;

  /// Idade que a pessoa completa no ano informado.
  int? ageInYear(int year) => birthDate == null ? null : year - birthDate!.year;

  bool matches(String search) {
    final term = search.trim().toLowerCase();
    if (term.isEmpty) return true;
    return [
      fullName,
      ministryRole,
      phone,
      email,
      cpf,
    ].whereType<String>().any((value) => value.toLowerCase().contains(term));
  }
}

/// Dados do formulário de cadastro, no formato esperado pela API.
class NewMember {
  const NewMember({
    required this.id,
    required this.fullName,
    this.birthDate,
    this.rg,
    this.cpf,
    this.maritalStatus,
    this.motherName,
    this.fatherName,
    this.spouseName,
    this.address,
    this.nationality,
    this.birthplace,
    this.ministryRole,
    this.ministryRoleSince,
    this.holySpiritBaptism,
    this.holySpiritBaptismDate,
    this.education,
    this.childrenCount,
    this.phone,
    this.email,
  });

  /// Gerado no app para que o reenvio offline não duplique o cadastro.
  final String id;
  final String fullName;
  final String? birthDate;
  final String? rg;
  final String? cpf;
  final String? maritalStatus;
  final String? motherName;
  final String? fatherName;
  final String? spouseName;
  final String? address;
  final String? nationality;
  final String? birthplace;
  final String? ministryRole;
  final String? ministryRoleSince;
  final bool? holySpiritBaptism;
  final String? holySpiritBaptismDate;
  final String? education;
  final int? childrenCount;
  final String? phone;
  final String? email;

  Map<String, Object?> toJson(String congregationId) => {
    'id': id,
    'congregationId': congregationId,
    'fullName': fullName,
    'birthDate': ?birthDate,
    'rg': ?rg,
    'cpf': ?cpf,
    'maritalStatus': ?maritalStatus,
    'motherName': ?motherName,
    'fatherName': ?fatherName,
    'spouseName': ?spouseName,
    'address': ?address,
    'nationality': ?nationality,
    'birthplace': ?birthplace,
    'ministryRole': ?ministryRole,
    'ministryRoleSince': ?ministryRoleSince,
    'holySpiritBaptism': ?holySpiritBaptism,
    'holySpiritBaptismDate': ?holySpiritBaptismDate,
    'education': ?education,
    'childrenCount': ?childrenCount,
    'phone': ?phone,
    'email': ?email,
  };
}
