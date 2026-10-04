import { carryOverBalances, nextDay, summarizeCycle } from './cycle-summary';

describe('summarizeCycle', () => {
  it('reproduz o ciclo 10/08/2026–13/09/2026 da planilha', () => {
    const summary = summarizeCycle({
      opening: { OFERTAS_CULTO: 11, OFERTAS_ALCADAS: 445.94, DIZIMOS: 0 },
      revenueByFund: { OFERTAS_CULTO: 79.25, OFERTAS_ALCADAS: 115.4, DIZIMOS: 887 },
      expensesByFund: { OFERTAS_CULTO: 54.98, DIZIMOS: 350 },
      leaderPercentage: 20,
    });

    expect(summary.funds.OFERTAS_CULTO.closing).toBe(35.27);
    expect(summary.funds.OFERTAS_ALCADAS.closing).toBe(561.34);
    expect(summary.tithe.balanceBeforeTransfers).toBe(537);
    expect(summary.tithe.leaderAmount).toBe(177.4);
    expect(summary.tithe.headquartersAmount).toBe(359.6);
    expect(summary.tithe.headquartersNegative).toBe(false);
  });

  it('sinaliza repasse negativo para a sede quando as despesas superam 80% dos dízimos', () => {
    const summary = summarizeCycle({
      opening: {},
      revenueByFund: { DIZIMOS: 100 },
      expensesByFund: { DIZIMOS: 90 },
      leaderPercentage: 20,
    });

    expect(summary.tithe.headquartersAmount).toBe(-10);
    expect(summary.tithe.headquartersNegative).toBe(true);
  });
});

describe('carryOverBalances', () => {
  it('zera os dízimos após os repasses e mantém as ofertas', () => {
    const opening = carryOverBalances(
      { OFERTAS_CULTO: 35.27, OFERTAS_ALCADAS: 561.34, DIZIMOS: 537 },
      { DIZIMOS: 177.4 + 359.6 },
    );

    expect(opening).toEqual({ OFERTAS_CULTO: 35.27, OFERTAS_ALCADAS: 561.34, DIZIMOS: 0 });
  });
});

describe('nextDay', () => {
  it('avança a data respeitando a virada do mês', () => {
    expect(nextDay('2026-10-11')).toBe('2026-10-12');
    expect(nextDay('2026-10-31')).toBe('2026-11-01');
  });
});
