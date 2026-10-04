import 'package:flutter/material.dart';

/// Linha "rótulo .......... valor", no estilo das linhas da planilha.
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
    this.indent = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final style = emphasized
        ? base?.copyWith(fontWeight: FontWeight.bold)
        : base;
    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: 4, left: indent ? 16 : 0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}
