import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

/// Campo de data dos formulários (abre o calendário ao tocar).
/// Participa da validação do `Form`: obrigatório, fica vermelho se vazio.
class DateField extends FormField<DateTime> {
  DateField({
    super.key,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool isRequired = false,
    DateTime? firstDate,
    DateTime? lastDate,
  }) : super(
         initialValue: value,
         validator: (current) =>
             isRequired && current == null ? 'Campo obrigatório.' : null,
         builder: (state) {
           Future<void> pick() async {
             final now = DateTime.now();
             final selected = await showDatePicker(
               context: state.context,
               firstDate: firstDate ?? DateTime(1900),
               lastDate: lastDate ?? now,
               initialDate: state.value ?? now,
               initialEntryMode: DatePickerEntryMode.input,
             );
             if (selected == null) return;
             state.didChange(selected);
             onChanged(selected);
           }

           void clear() {
             state.didChange(null);
             onChanged(null);
           }

           return InkWell(
             onTap: pick,
             child: InputDecorator(
               decoration: InputDecoration(
                 labelText: isRequired ? '$label *' : label,
                 border: const OutlineInputBorder(),
                 errorText: state.errorText,
                 suffixIcon: state.value == null
                     ? const Icon(Icons.calendar_month)
                     : IconButton(
                         tooltip: 'Limpar',
                         icon: const Icon(Icons.close),
                         onPressed: clear,
                       ),
               ),
               child: Text(
                 state.value == null ? 'Selecionar' : formatDate(state.value),
               ),
             ),
           );
         },
       );
}
