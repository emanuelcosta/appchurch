/// Formata no padrão brasileiro: R$ 1.234,56.
String formatMoney(double value) {
  final cents = (value.abs() * 100).round();
  final integer = (cents ~/ 100).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    if (i > 0 && (integer.length - i) % 3 == 0) buffer.write('.');
    buffer.write(integer[i]);
  }
  final decimals = (cents % 100).toString().padLeft(2, '0');
  return '${value < 0 && cents > 0 ? '-' : ''}R\$ $buffer,$decimals';
}

/// Lê valor digitado no padrão brasileiro ("1.234,56", "12,5" ou "12.5").
double? parseMoney(String text) {
  var value = text.replaceAll('R\$', '').replaceAll(' ', '').trim();
  if (value.isEmpty) return null;
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(value);
}

/// Valor para preencher um campo de digitação: 1234.5 → "1234,50".
String formatMoneyInput(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

/// Formata como dd/mm/aaaa.
String formatDate(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// Formata como aaaa-mm-dd, o formato aceito pela API.
String toIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

const monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];
