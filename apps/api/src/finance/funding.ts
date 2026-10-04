import { FUNDS, round2 } from './cycle-summary';

const brl = (value: number) => `R$ ${value.toFixed(2).replace('.', ',')}`;

/**
 * Valida as fontes do dinheiro de um pagamento: fundos conhecidos,
 * valores positivos e soma igual ao valor pago (tolerância de 1 centavo).
 * Retorna a mensagem de erro ou `null` quando está tudo certo.
 */
export function validateFundingSources(
  amount: number,
  sources: Record<string, unknown> | undefined,
): string | null {
  const entries = Object.entries(sources ?? {}).filter(([, value]) => Number(value) !== 0);
  if (entries.length === 0) return 'Informe de quais fontes sai o dinheiro.';
  for (const [fund, value] of entries) {
    if (!(FUNDS as readonly string[]).includes(fund)) return `Fonte desconhecida: ${fund}.`;
    if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
      return 'Os valores das fontes devem ser positivos.';
    }
  }
  const total = round2(entries.reduce((sum, [, value]) => sum + Number(value), 0));
  const difference = round2(round2(amount) - total);
  if (Math.abs(difference) >= 0.01) {
    return difference > 0
      ? `As fontes somam ${brl(total)}; faltam ${brl(difference)} para o valor da despesa.`
      : `As fontes somam ${brl(total)}; passam ${brl(-difference)} do valor da despesa.`;
  }
  return null;
}
