import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { CreateCycleDto } from './dto/create-cycle.dto';
import { CreateEntryDto } from './dto/create-entry.dto';
import { CreateExpenseCategoryDto } from './dto/create-expense-category.dto';
import { CreatePayableDto } from './dto/create-payable.dto';
import { CreatePayablePaymentDto } from './dto/create-payable-payment.dto';

type Cycle = CreateCycleDto & {
  id: string;
  status: 'OPEN';
  openingBalance: number;
  createdAt: string;
  createdBy: string;
};

type Entry = CreateEntryDto & {
  id: string;
  status: 'CONFIRMED';
  createdAt: string;
  createdBy: string;
};

type ExpenseCategory = CreateExpenseCategoryDto & { id: string; active: boolean };
type Payable = CreatePayableDto & {
  id: string;
  status: 'OPEN' | 'OVERDUE' | 'PARTIALLY_PAID' | 'PAID';
  createdAt: string;
};
type PayablePayment = CreatePayablePaymentDto & {
  id: string;
  payableId: string;
  createdAt: string;
};

@Injectable()
export class FinanceService {
  private readonly cycles = new Map<string, Cycle>();
  private readonly entries = new Map<string, Entry>();
  private readonly categories = new Map<string, ExpenseCategory>();
  private readonly payables = new Map<string, Payable>();
  private readonly notificationDays = new Map<string, number>();
  private readonly payablePayments = new Map<string, PayablePayment[]>();

  createExpenseCategory(dto: CreateExpenseCategoryDto): ExpenseCategory {
    const category: ExpenseCategory = {
      ...dto,
      id: randomUUID(),
      active: true,
    };
    this.categories.set(category.id, category);
    return category;
  }

  listExpenseCategories(congregationId: string): ExpenseCategory[] {
    return [...this.categories.values()].filter(
      (category) => category.congregationId === congregationId && category.active,
    );
  }

  setNotificationDays(congregationId: string, days: number): { congregationId: string; days: number } {
    if (!Number.isInteger(days) || days < 0 || days > 365) {
      throw new BadRequestException('A antecedência deve estar entre 0 e 365 dias.');
    }
    this.notificationDays.set(congregationId, days);
    return { congregationId, days };
  }

  getNotificationDays(congregationId: string): number {
    return this.notificationDays.get(congregationId) ?? 3;
  }

  createPayable(dto: CreatePayableDto): Payable {
    const cycle = this.cycles.get(dto.cycleId);
    const category = this.categories.get(dto.categoryId);
    if (!cycle || cycle.congregationId !== dto.congregationId) {
      throw new NotFoundException('Ciclo não encontrado para esta congregação.');
    }
    if (!category || category.congregationId !== dto.congregationId || !category.active) {
      throw new NotFoundException('Categoria de despesa não encontrada ou inativa.');
    }
    if (dto.dueDate < dto.issueDate) {
      throw new BadRequestException('O vencimento não pode ser anterior à data da conta.');
    }
    const sourceTotal = Object.values(dto.fundingSources).reduce((sum, value) => sum + value, 0);
    const allowedSources = new Set(['DIZIMOS', 'OFERTAS_CULTO', 'OFERTAS_ALCADAS']);
    if (
      Object.keys(dto.fundingSources).length === 0 ||
      Object.entries(dto.fundingSources).some(
        ([source, value]) => !allowedSources.has(source) || value <= 0,
      ) ||
      Math.abs(sourceTotal - dto.amount) > 0.0001
    ) {
      throw new BadRequestException(
        'A soma das origens deve ser igual ao valor da conta e usar origens válidas.',
      );
    }
    const payable: Payable = {
      ...dto,
      notificationDaysBefore: dto.notificationDaysBefore ?? this.getNotificationDays(dto.congregationId),
      id: randomUUID(),
      status: dto.dueDate < new Date().toISOString().slice(0, 10) ? 'OVERDUE' : 'OPEN',
      createdAt: new Date().toISOString(),
    };
    this.payables.set(payable.id, payable);
    this.payablePayments.set(payable.id, []);
    return payable;
  }

  listPayables(congregationId: string): Payable[] {
    return [...this.payables.values()].filter((payable) => payable.congregationId === congregationId);
  }

  registerPayablePayment(
    congregationId: string,
    payableId: string,
    dto: CreatePayablePaymentDto,
  ) {
    const payable = this.payables.get(payableId);
    if (!payable || payable.congregationId !== congregationId) {
      throw new NotFoundException('Conta a pagar não encontrada para esta congregação.');
    }
    if (!['CASH', 'PIX'].includes(dto.paymentMethod)) {
      throw new BadRequestException('O pagamento deve ser em espécie ou PIX.');
    }
    const sourceTotal = Object.values(dto.fundingSources).reduce((sum, value) => sum + value, 0);
    const allowedSources = new Set(['DIZIMOS', 'OFERTAS_CULTO', 'OFERTAS_ALCADAS']);
    if (
      Object.keys(dto.fundingSources).length === 0 ||
      Object.entries(dto.fundingSources).some(
        ([source, value]) => !allowedSources.has(source) || value <= 0,
      ) ||
      Math.abs(sourceTotal - dto.amount) > 0.0001
    ) {
      throw new BadRequestException(
        'A soma das origens do pagamento deve ser igual ao valor pago.',
      );
    }
    const payments = this.payablePayments.get(payableId) ?? [];
    const paidAmount = payments.reduce((sum, payment) => sum + payment.amount, 0);
    const remainingAmount = payable.amount - paidAmount;
    if (dto.amount > remainingAmount + 0.0001) {
      throw new BadRequestException('O pagamento não pode exceder o saldo da conta.');
    }
    const payment: PayablePayment = {
      ...dto,
      id: randomUUID(),
      payableId,
      createdAt: new Date().toISOString(),
    };
    payments.push(payment);
    this.payablePayments.set(payableId, payments);
    const newPaidAmount = paidAmount + dto.amount;
    payable.status = newPaidAmount >= payable.amount - 0.0001 ? 'PAID' : 'PARTIALLY_PAID';
    return {
      payable,
      payment,
      paidAmount: newPaidAmount,
      remainingAmount: Math.max(0, payable.amount - newPaidAmount),
    };
  }

  listPayablePayments(congregationId: string, payableId: string): PayablePayment[] {
    const payable = this.payables.get(payableId);
    if (!payable || payable.congregationId !== congregationId) {
      throw new NotFoundException('Conta a pagar não encontrada para esta congregação.');
    }
    return this.payablePayments.get(payableId) ?? [];
  }

  createCycle(dto: CreateCycleDto): Cycle {
    if (dto.startDate > dto.endDate) {
      throw new BadRequestException({
        code: 'INVALID_CYCLE_DATES',
        message: 'A data inicial deve ser anterior ou igual à data final.',
      });
    }
    const cycle: Cycle = {
      ...dto,
      id: randomUUID(),
      status: 'OPEN',
      createdAt: new Date().toISOString(),
      createdBy: 'local-development',
    };
    this.cycles.set(cycle.id, cycle);
    return cycle;
  }

  listCycles(congregationId: string): Cycle[] {
    return [...this.cycles.values()].filter((cycle) => cycle.congregationId === congregationId);
  }

  createEntry(dto: CreateEntryDto): Entry {
    const cycle = this.cycles.get(dto.cycleId);
    if (!cycle || cycle.congregationId !== dto.congregationId) {
      throw new NotFoundException({
        code: 'CYCLE_NOT_FOUND',
        message: 'Ciclo não encontrado para esta congregação.',
      });
    }
    const allowedPaymentMethods = new Set(['CASH', 'PIX']);
    const paymentMethods = Object.entries(dto.paymentLines);
    if (
      paymentMethods.length === 0 ||
      paymentMethods.some(
        ([method, value]) =>
          !allowedPaymentMethods.has(method) || !Number.isFinite(value) || value <= 0,
      )
    ) {
      throw new BadRequestException({
        code: 'INVALID_PAYMENT_METHOD',
        message: 'Informe dinheiro em espécie e/ou PIX com valores positivos.',
      });
    }
    const lineTotal = Object.values(dto.paymentLines).reduce((sum, value) => sum + value, 0);
    if (Math.abs(lineTotal - dto.totalAmount) > 0.0001) {
      throw new BadRequestException({
        code: 'ENTRY_LINES_TOTAL_MISMATCH',
        message: 'A soma dos meios de pagamento deve ser igual ao total.',
      });
    }
    const entry: Entry = {
      ...dto,
      id: randomUUID(),
      status: 'CONFIRMED',
      createdAt: new Date().toISOString(),
      createdBy: 'local-development',
    };
    this.entries.set(entry.id, entry);
    return entry;
  }

  listEntries(congregationId: string, cycleId?: string): Entry[] {
    return [...this.entries.values()].filter(
      (entry) =>
        entry.congregationId === congregationId &&
        (cycleId === undefined || entry.cycleId === cycleId),
    );
  }

  getBalance(congregationId: string, cycleId: string): number {
    const cycle = this.cycles.get(cycleId);
    if (!cycle || cycle.congregationId !== congregationId) {
      throw new NotFoundException({
        code: 'CYCLE_NOT_FOUND',
        message: 'Ciclo não encontrado para esta congregação.',
      });
    }
    return cycle.openingBalance + this.listEntries(congregationId, cycleId)
      .reduce((sum, entry) => sum + entry.totalAmount, 0);
  }

  getBalanceByRevenueType(congregationId: string, cycleId: string) {
    const entries = this.listEntries(congregationId, cycleId);
    const totals = new Map<string, number>();
    for (const entry of entries) {
      totals.set(
        entry.entryTypeId,
        (totals.get(entry.entryTypeId) ?? 0) + entry.totalAmount,
      );
    }
    for (const payable of this.listPayables(congregationId).filter(
      (item) =>
        item.cycleId === cycleId &&
        (item.status === 'PARTIALLY_PAID' || item.status === 'PAID'),
    )) {
      const paidAmount = (this.payablePayments.get(payable.id) ?? []).reduce(
        (sum, payment) => sum + payment.amount,
        0,
      );
      for (const payment of this.payablePayments.get(payable.id) ?? []) {
        for (const [source, amount] of Object.entries(payment.fundingSources)) {
          totals.set(source, (totals.get(source) ?? 0) - amount);
        }
      }
    }
    return [...totals.entries()].map(([entryTypeId, totalAmount]) => ({
      congregationId,
      cycleId,
      entryTypeId,
      totalAmount,
    }));
  }

  getBalanceByRevenueCategory(congregationId: string, cycleId: string) {
    const entries = this.listEntries(congregationId, cycleId);
    const totals = new Map<string, number>();
    for (const entry of entries) {
      const categoryId = entry.revenueCategoryId ?? 'WITHOUT_CATEGORY';
      totals.set(categoryId, (totals.get(categoryId) ?? 0) + entry.totalAmount);
    }
    return [...totals.entries()].map(([revenueCategoryId, totalAmount]) => ({
      congregationId,
      cycleId,
      revenueCategoryId,
      totalAmount,
    }));
  }
}
