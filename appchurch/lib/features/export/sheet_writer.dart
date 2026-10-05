import 'package:excel/excel.dart';

/// Formato de dinheiro nas planilhas exportadas (R$ 1.234,56 no Excel em
/// português).
const _moneyFormat = CustomNumericNumFormat(formatCode: '"R\$" #,##0.00');

/// Valor de célula: texto, dinheiro, número inteiro ou data.
sealed class XlsxValue {
  const XlsxValue();
}

class XText extends XlsxValue {
  const XText(this.text);
  final String? text;
}

class XMoney extends XlsxValue {
  const XMoney(this.value);
  final double value;
}

class XInt extends XlsxValue {
  const XInt(this.value);
  final int? value;
}

class XDate extends XlsxValue {
  const XDate(this.value);
  final DateTime? value;
}

/// Escreve uma aba da planilha linha a linha, com título, cabeçalho em
/// negrito, valores tipados (dinheiro e data reais do Excel) e largura das
/// colunas ajustada ao conteúdo.
class SheetWriter {
  SheetWriter(this._excel, this.name);

  final Excel _excel;
  final String name;
  int _row = 0;
  final _widths = <int, double>{};

  Sheet get _sheet => _excel[name];

  /// Linha de título (negrito, maior).
  void title(String text) {
    _write([XText(text)], CellStyle(bold: true, fontSize: 14));
  }

  /// Linha de texto simples (ex.: período, observação).
  void note(String text) {
    _write([XText(text)], CellStyle(italic: true));
  }

  void blank() => _row++;

  /// Cabeçalho da tabela (negrito, fundo cinza).
  void header(List<String> labels) {
    _write([
      for (final label in labels) XText(label),
    ], CellStyle(bold: true, backgroundColorHex: ExcelColor.grey300));
  }

  void row(List<XlsxValue> values, {bool bold = false}) {
    _write(values, bold ? CellStyle(bold: true) : null);
  }

  /// Linha "rótulo: valor" do resumo, no estilo da aba RELATORIO_MENSAL.
  void labelValue(String label, double value, {bool bold = false}) {
    row([XText(label), XMoney(value)], bold: bold);
  }

  void _write(List<XlsxValue> values, CellStyle? style) {
    for (var column = 0; column < values.length; column++) {
      final value = values[column];
      final cell = _sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: _row),
      );
      cell.value = switch (value) {
        XText(:final text) => text == null ? null : TextCellValue(text),
        XMoney(:final value) => DoubleCellValue(_round(value)),
        XInt(:final value) => value == null ? null : IntCellValue(value),
        XDate(:final value) =>
          value == null
              ? null
              : DateCellValue(
                  year: value.year,
                  month: value.month,
                  day: value.day,
                ),
      };
      final cellStyle = switch (value) {
        XMoney() => (style ?? CellStyle()).copyWith(numberFormat: _moneyFormat),
        XDate() => (style ?? CellStyle()).copyWith(
          numberFormat: NumFormat.standard_14,
        ),
        _ => style,
      };
      if (cellStyle != null) cell.cellStyle = cellStyle;
      _trackWidth(column, value);
    }
    _row++;
  }

  void _trackWidth(int column, XlsxValue value) {
    final length = switch (value) {
      XText(:final text) => (text ?? '').length,
      XMoney() => 14,
      XDate() => 12,
      XInt() => 6,
    };
    final width = (length + 2).clamp(8, 60).toDouble();
    if (width > (_widths[column] ?? 0)) _widths[column] = width;
  }

  /// Aplica as larguras das colunas (chamar ao terminar a aba).
  void finish() {
    for (final MapEntry(key: column, value: width) in _widths.entries) {
      _sheet.setColumnWidth(column, width);
    }
  }

  static double _round(double value) => (value * 100).round() / 100;
}

/// Cria a planilha já sem a aba padrão "Sheet1".
Excel newWorkbook(String firstSheet) {
  final excel = Excel.createExcel();
  excel.rename(excel.getDefaultSheet() ?? 'Sheet1', firstSheet);
  excel.setDefaultSheet(firstSheet);
  return excel;
}
