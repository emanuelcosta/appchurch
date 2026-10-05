import '../../core/utils/formatters.dart';
import '../members/member.dart';
import 'sheet_writer.dart';

/// Planilha de membros com a ficha completa, nas colunas da planilha
/// membros.xlsx. Contém dados pessoais (LGPD): só gerar a pedido do usuário.
List<int> buildMembersWorkbook(
  List<Member> members, {
  String? congregationName,
}) {
  final excel = newWorkbook('Membros');
  final sheet = SheetWriter(excel, 'Membros')
    ..title('${congregationName ?? 'Congregação'} — Membros')
    ..note(
      'Gerado em ${formatDate(DateTime.now())} • ${members.length} membro(s). '
      'Contém dados pessoais: compartilhe somente com quem precisa.',
    )
    ..blank()
    ..header([
      'Nome',
      'Data de nascimento',
      'RG',
      'Estado civil',
      'CPF',
      'Filiação mãe',
      'Filiação pai',
      'Cônjuge',
      'Endereço',
      'Nacionalidade',
      'Naturalidade',
      'Função ministerial',
      'Função desde',
      'Batizado no Espírito Santo',
      'Data batismo no Espírito Santo',
      'Escolaridade',
      'Nº filhos',
      'Telefone',
      'E-mail',
    ]);
  final sorted = [...members]
    ..sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  for (final member in sorted) {
    sheet.row([
      XText(member.fullName),
      XDate(member.birthDate),
      XText(member.rg),
      XText(member.maritalStatus),
      XText(member.cpf),
      XText(member.motherName),
      XText(member.fatherName),
      XText(member.spouseName),
      XText(member.address),
      XText(member.nationality),
      XText(member.birthplace),
      XText(member.ministryRole),
      XDate(member.ministryRoleSince),
      XText(switch (member.holySpiritBaptism) {
        true => 'Sim',
        false => 'Não',
        null => null,
      }),
      XDate(member.holySpiritBaptismDate),
      XText(member.education),
      XInt(member.childrenCount),
      XText(member.phone),
      XText(member.email),
    ]);
  }
  sheet.finish();
  return excel.encode()!;
}
