/** Data de hoje (`yyyy-mm-dd`) no fuso da congregação, não em UTC. */
export function todayInBrazil(now = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(now);
}

/**
 * Valida um período de busca (`yyyy-mm-dd`). Retorna a mensagem de erro
 * ou `null` quando o período é válido.
 */
export function periodError(from: string, to: string): string | null {
  const iso = /^\d{4}-\d{2}-\d{2}$/;
  const valid = (value: string) =>
    iso.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`)) &&
    new Date(`${value}T00:00:00Z`).toISOString().startsWith(value);
  if (!valid(from) || !valid(to)) return 'Período inválido. Use datas no formato aaaa-mm-dd.';
  if (from > to) return 'A data inicial do período é posterior à data final.';
  return null;
}

/**
 * Emissão de uma conta a pagar lançada hoje. O banco exige
 * `due_date >= issue_date`; uma conta já vencida é emitida no vencimento.
 */
export function payableIssueDate(dueDate: string, today: string): string {
  return dueDate < today ? dueDate : today;
}
