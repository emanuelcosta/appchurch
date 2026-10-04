import { BadRequestException } from '@nestjs/common';
import { FinanceService } from './finance.service';

const congregationId = '11111111-1111-4111-8111-111111111111';
const entryTypeId = '22222222-2222-4222-8222-222222222222';

describe('FinanceService', () => {
  it('creates a cycle and calculates confirmed revenue balance', () => {
    const service = new FinanceService();
    const cycle = service.createCycle({
      congregationId,
      name: 'Ciclo inicial',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      openingBalance: 100,
    });

    service.createEntry({
      congregationId,
      cycleId: cycle.id,
      entryTypeId,
      entryDate: '2026-10-03',
      description: 'Oferta de culto',
      totalAmount: 50,
      paymentLines: { PIX: 50 },
    });

    expect(service.getBalance(congregationId, cycle.id)).toBe(150);
  });

  it('rejects payment lines with an incorrect total', () => {
    const service = new FinanceService();
    const cycle = service.createCycle({
      congregationId,
      name: 'Ciclo inicial',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      openingBalance: 0,
    });

    expect(() =>
      service.createEntry({
        congregationId,
        cycleId: cycle.id,
        entryTypeId,
        entryDate: '2026-10-03',
        description: 'Oferta',
        totalAmount: 50,
        paymentLines: { PIX: 40 },
      }),
    ).toThrow(BadRequestException);
  });

  it('accepts cash and PIX as separate payment lines', () => {
    const service = new FinanceService();
    const cycle = service.createCycle({
      congregationId,
      name: 'Ciclo meios',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      openingBalance: 0,
    });
    const entry = service.createEntry({
      congregationId,
      cycleId: cycle.id,
      entryTypeId,
      entryDate: '2026-10-03',
      description: 'Oferta dividida',
      totalAmount: 100,
      paymentLines: { CASH: 40, PIX: 60 },
    });
    expect(entry.paymentLines).toEqual({ CASH: 40, PIX: 60 });
  });

  it('rejects an unsupported payment method', () => {
    const service = new FinanceService();
    const cycle = service.createCycle({
      congregationId,
      name: 'Ciclo método inválido',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      openingBalance: 0,
    });
    expect(() =>
      service.createEntry({
        congregationId,
        cycleId: cycle.id,
        entryTypeId,
        entryDate: '2026-10-03',
        description: 'Oferta',
        totalAmount: 10,
        paymentLines: { CARD: 10 },
      }),
    ).toThrow(BadRequestException);
  });

  it('requires an active category and creates a payable with configured notice days', () => {
    const service = new FinanceService();
    const cycle = service.createCycle({
      congregationId,
      name: 'Ciclo contas',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      openingBalance: 0,
    });
    const category = service.createExpenseCategory({
      congregationId,
      name: 'Manutenção',
    });
    service.setNotificationDays(congregationId, 7);

    const payable = service.createPayable({
      congregationId,
      cycleId: cycle.id,
      categoryId: category.id,
      fundingSources: { DIZIMOS: 250 },
      description: 'Conta de energia',
      issueDate: '2026-10-03',
      dueDate: '2026-10-20',
      amount: 250,
    });

    expect(payable.notificationDaysBefore).toBe(7);
    expect(service.listPayables(congregationId)).toHaveLength(1);
  });

  it('rejects a payable with a due date before its issue date', () => {
    const service = new FinanceService();
    const cycle = service.createCycle({
      congregationId,
      name: 'Ciclo inválido',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      openingBalance: 0,
    });
    const category = service.createExpenseCategory({
      congregationId,
      name: 'Serviços',
    });

    expect(() =>
      service.createPayable({
        congregationId,
        cycleId: cycle.id,
        categoryId: category.id,
        fundingSources: { DIZIMOS: 10 },
        description: 'Conta inválida',
        issueDate: '2026-10-20',
        dueDate: '2026-10-19',
        amount: 10,
      }),
    ).toThrow(BadRequestException);
  });

  it('returns revenue balances separated by type and category', () => {
    const service = new FinanceService();
    const cycle = service.createCycle({
      congregationId,
      name: 'Ciclo por tipo',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      openingBalance: 0,
    });

    service.createEntry({
      congregationId,
      cycleId: cycle.id,
      entryTypeId,
      revenueCategoryId: '44444444-4444-4444-8444-444444444444',
      entryDate: '2026-10-03',
      description: 'Oferta alçada - manutenção',
      totalAmount: 80,
      paymentLines: { PIX: 80 },
    });
    service.createEntry({
      congregationId,
      cycleId: cycle.id,
      entryTypeId,
      revenueCategoryId: '55555555-5555-4555-8555-555555555555',
      entryDate: '2026-10-04',
      description: 'Oferta alçada - ação social',
      totalAmount: 20,
      paymentLines: { CASH: 20 },
    });

    expect(service.getBalanceByRevenueType(congregationId, cycle.id)).toEqual([
      { congregationId, cycleId: cycle.id, entryTypeId, totalAmount: 100 },
    ]);
    expect(service.getBalanceByRevenueCategory(congregationId, cycle.id)).toHaveLength(2);
  });

  it('closes a payable after full payment and supports partial payment', () => {
    const service = new FinanceService();
    const cycle = service.createCycle({
      congregationId,
      name: 'Ciclo pagamentos',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      openingBalance: 0,
    });
    const category = service.createExpenseCategory({
      congregationId,
      name: 'Manutenção',
    });
    const payable = service.createPayable({
      congregationId,
      cycleId: cycle.id,
      categoryId: category.id,
      fundingSources: { DIZIMOS: 100 },
      description: 'Conta parcelada',
      issueDate: '2026-10-03',
      dueDate: '2026-10-20',
      amount: 100,
    });

    const partial = service.registerPayablePayment(congregationId, payable.id, {
      paymentDate: '2026-10-05',
      amount: 40,
      paymentMethod: 'PIX',
      fundingSources: { DIZIMOS: 40 },
    });
    expect(partial.payable.status).toBe('PARTIALLY_PAID');
    expect(partial.remainingAmount).toBe(60);

    const closed = service.registerPayablePayment(congregationId, payable.id, {
      paymentDate: '2026-10-06',
      amount: 60,
      paymentMethod: 'CASH',
      fundingSources: { DIZIMOS: 60 },
    });
    expect(closed.payable.status).toBe('PAID');
    expect(closed.remainingAmount).toBe(0);
  });
});
