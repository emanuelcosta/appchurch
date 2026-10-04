import { payableIssueDate, periodError, todayInBrazil } from './dates';

describe('periodError', () => {
  it('aceita período válido, inclusive de um dia só', () => {
    expect(periodError('2026-01-01', '2026-10-04')).toBeNull();
    expect(periodError('2026-10-04', '2026-10-04')).toBeNull();
  });

  it('recusa datas inválidas ou invertidas', () => {
    expect(periodError('2026-02-30', '2026-03-01')).toMatch(/inválido/);
    expect(periodError('04/10/2026', '2026-10-04')).toMatch(/inválido/);
    expect(periodError('2026-10-05', '2026-10-04')).toMatch(/posterior/);
  });
});

describe('todayInBrazil', () => {
  it('usa o fuso de São Paulo, não UTC', () => {
    // 01:30 UTC de 05/10 ainda é 04/10 no Brasil.
    expect(todayInBrazil(new Date('2026-10-05T01:30:00Z'))).toBe('2026-10-04');
    expect(todayInBrazil(new Date('2026-10-05T12:00:00Z'))).toBe('2026-10-05');
  });
});

describe('payableIssueDate', () => {
  it('emite hoje quando o vencimento é hoje ou futuro', () => {
    expect(payableIssueDate('2026-10-04', '2026-10-04')).toBe('2026-10-04');
    expect(payableIssueDate('2026-11-10', '2026-10-04')).toBe('2026-10-04');
  });

  it('conta já vencida é emitida no vencimento (due_date >= issue_date)', () => {
    expect(payableIssueDate('2026-09-20', '2026-10-04')).toBe('2026-09-20');
  });
});
