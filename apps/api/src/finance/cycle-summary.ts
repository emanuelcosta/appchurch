export const FUNDS = ['OFERTAS_CULTO', 'OFERTAS_ALCADAS', 'DIZIMOS'] as const;
export type FundCode = (typeof FUNDS)[number];

export type FundSummary = {
  opening: number;
  revenue: number;
  expenses: number;
  closing: number;
};

export type TitheSummary = {
  gross: number;
  expenses: number;
  leaderPercentage: number;
  leaderAmount: number;
  headquartersAmount: number;
  balanceBeforeTransfers: number;
  headquartersNegative: boolean;
};

export type CycleSummary = {
  funds: Record<FundCode, FundSummary>;
  tithe: TitheSummary;
};

export type CycleSummaryInput = {
  opening: Partial<Record<string, number>>;
  revenueByFund: Partial<Record<string, number>>;
  expensesByFund: Partial<Record<string, number>>;
  leaderPercentage: number;
};

export const round2 = (value: number) => Math.round(value * 100) / 100;

/**
 * Regras do dashboard da planilha:
 * - saldo de cada fundo = saldo anterior + entradas - despesas pagas no período;
 * - dízimos: dirigente recebe o percentual sobre o bruto e a sede recebe
 *   bruto - dirigente - despesas pagas com dízimos (repasses zeram o fundo).
 */
export function summarizeCycle(input: CycleSummaryInput): CycleSummary {
  const funds = {} as Record<FundCode, FundSummary>;
  for (const fund of FUNDS) {
    const opening = input.opening[fund] ?? 0;
    const revenue = input.revenueByFund[fund] ?? 0;
    const expenses = input.expensesByFund[fund] ?? 0;
    funds[fund] = {
      opening: round2(opening),
      revenue: round2(revenue),
      expenses: round2(expenses),
      closing: round2(opening + revenue - expenses),
    };
  }
  const gross = funds.DIZIMOS.revenue;
  const leaderAmount = round2((gross * input.leaderPercentage) / 100);
  const headquartersAmount = round2(gross - leaderAmount - funds.DIZIMOS.expenses);
  return {
    funds,
    tithe: {
      gross,
      expenses: funds.DIZIMOS.expenses,
      leaderPercentage: input.leaderPercentage,
      leaderAmount,
      headquartersAmount,
      balanceBeforeTransfers: funds.DIZIMOS.closing,
      headquartersNegative: headquartersAmount < 0,
    },
  };
}

/** Saldo que passa para o próximo ciclo: fechamento menos os repasses do fundo. */
export function carryOverBalances(
  closingByFund: Partial<Record<string, number>>,
  transfersByFund: Partial<Record<string, number>>,
): Record<FundCode, number> {
  const result = {} as Record<FundCode, number>;
  for (const fund of FUNDS) {
    result[fund] = round2((closingByFund[fund] ?? 0) - (transfersByFund[fund] ?? 0));
  }
  return result;
}

/** Soma o dia seguinte a uma data ISO (yyyy-mm-dd). */
export function nextDay(isoDate: string): string {
  const date = new Date(`${isoDate}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}
