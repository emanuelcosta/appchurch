import { validateFundingSources } from './funding';

describe('validateFundingSources', () => {
  it('aceita fontes que somam o valor da despesa', () => {
    expect(validateFundingSources(300, { OFERTAS_CULTO: 100, DIZIMOS: 200 })).toBeNull();
    expect(validateFundingSources(0.3, { OFERTAS_CULTO: 0.1, DIZIMOS: 0.2 })).toBeNull();
  });

  it('informa quanto falta ou quanto passa', () => {
    expect(validateFundingSources(300, { DIZIMOS: 250 })).toContain('faltam R$ 50,00');
    expect(validateFundingSources(300, { DIZIMOS: 320 })).toContain('passam R$ 20,00');
  });

  it('recusa fontes vazias, desconhecidas ou negativas', () => {
    expect(validateFundingSources(10, {})).toContain('Informe');
    expect(validateFundingSources(10, { CAIXA: 10 })).toContain('desconhecida');
    expect(validateFundingSources(10, { DIZIMOS: 20, OFERTAS_CULTO: -10 })).toContain('positivos');
  });
});
