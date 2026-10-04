import { BadRequestException, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { round2 } from './cycle-summary';
import { payableIssueDate, periodError, todayInBrazil } from './dates';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { CreateRevenueDto } from './dto/create-revenue.dto';
import { PayPayableDto } from './dto/pay-payable.dto';
import { ReverseDto } from './dto/reverse.dto';
import { validateFundingSources } from './funding';
import { SupabaseRestService, SupabaseRow } from './supabase-rest.service';

const brDate = (iso: string) => iso.split('-').reverse().join('/');

/**
 * Lançamentos da tesouraria: receitas, despesas, pagamento de contas,
 * tipos/categorias e o extrato do ciclo. Todas as gravações são
 * idempotentes pelo id gerado no app (fila offline).
 */
@Injectable()
export class LedgerService {
  constructor(private readonly db: SupabaseRestService) {}

  // ---------------------------------------------------------------- extrato

  /**
   * Extrato do ciclo: receitas, despesas pagas e contas a pagar em aberto.
   * Com `period`, busca entre as datas informadas (pode cruzar vários
   * ciclos) em vez do ciclo selecionado.
   */
  async ledger(congregationId: string, cycleId?: string, period?: { from: string; to: string }) {
    if (period) {
      const error = periodError(period.from, period.to);
      if (error) throw new BadRequestException(error);
    }
    const closures = await this.db.query(
      'accountability_closures',
      `select=id,period_start,period_end,status&congregation_id=eq.${congregationId}&status=neq.CANCELLED&order=period_start.desc`,
    );
    const cycles = closures.map((row) => ({
      id: row.id, startDate: row.period_start, endDate: row.period_end, status: row.status,
    }));
    const selected =
      closures.find((row) => String(row.id) === cycleId) ??
      closures.find((row) => row.status === 'OPEN') ??
      closures[0];
    const pending = await this.pendingPayables(congregationId);
    if (!selected && !period) return { cycles, cycle: null, period: null, items: pending };

    const start = period ? period.from : String(selected!.period_start);
    const end = period ? period.to : selected!.status === 'OPEN' ? undefined : String(selected!.period_end);
    const range = (column: string) => `${column}=gte.${start}${end ? `&${column}=lte.${end}` : ''}`;
    const [entries, funds, revenueCategories, payments, payables, expenseCategories, allocations] = await Promise.all([
      this.db.query('financial_entries', `select=id,entry_date,description,total_amount,entry_type_id,revenue_category_id&congregation_id=eq.${congregationId}&status=eq.CONFIRMED&${range('entry_date')}`),
      this.db.query('entry_types', `select=id,code&congregation_id=eq.${congregationId}`),
      this.db.query('revenue_categories', `select=id,name&congregation_id=eq.${congregationId}`),
      this.db.query('payable_payments', `select=id,payable_id,payment_date,amount,payment_method&congregation_id=eq.${congregationId}&${range('payment_date')}`),
      this.db.query('payables', `select=id,description,category_id,issue_date,due_date,amount&congregation_id=eq.${congregationId}`),
      this.db.query('expense_categories', `select=id,name&congregation_id=eq.${congregationId}`),
      this.db.query('payable_funding_allocations', `select=payable_id,payment_id,revenue_type_code,amount&congregation_id=eq.${congregationId}`),
    ]);
    const fundOf = new Map(funds.map((row) => [String(row.id), String(row.code)]));
    const revenueCategoryOf = new Map(revenueCategories.map((row) => [String(row.id), String(row.name)]));
    const payableOf = new Map(payables.map((row) => [String(row.id), row]));
    const expenseCategoryOf = new Map(expenseCategories.map((row) => [String(row.id), String(row.name)]));
    const lines = entries.length
      ? await this.db.query('financial_entry_lines', `select=financial_entry_id,payment_method,amount&financial_entry_id=in.(${entries.map((row) => String(row.id)).join(',')})`)
      : [];
    const lineAmount = (entryId: unknown, method: string) => round2(
      lines
        .filter((line) => String(line.financial_entry_id) === String(entryId) && line.payment_method === method)
        .reduce((sum, line) => sum + Number(line.amount), 0),
    );

    const revenues = entries.map((row) => ({
      id: row.id,
      kind: 'REVENUE',
      date: row.entry_date,
      description: row.description,
      fundCode: fundOf.get(String(row.entry_type_id)) ?? 'OUTROS',
      categoryId: row.revenue_category_id ?? null,
      category: revenueCategoryOf.get(String(row.revenue_category_id)) ?? null,
      amount: Number(row.total_amount),
      pixAmount: lineAmount(row.id, 'PIX'),
      cashAmount: lineAmount(row.id, 'CASH'),
    }));
    const expenses = payments.map((payment) => {
      const payable = payableOf.get(String(payment.payable_id));
      return {
        id: payment.id,
        kind: 'EXPENSE',
        payableId: payment.payable_id,
        // Despesa lançada já paga (conta e pagamento na mesma data e valor).
        paidOnCreation:
          payable?.issue_date === payable?.due_date &&
          payable?.due_date === payment.payment_date &&
          Number(payable?.amount) === Number(payment.amount),
        date: payment.payment_date,
        description: payable?.description ?? 'Despesa',
        categoryId: payable?.category_id ?? null,
        category: expenseCategoryOf.get(String(payable?.category_id)) ?? null,
        paymentMethod: payment.payment_method,
        amount: Number(payment.amount),
        funds: this.paymentFunds(payment, allocations),
      };
    });
    return {
      cycles,
      cycle: period ? null : cycles.find((cycle) => cycle.id === selected!.id),
      period: period ?? null,
      items: [...pending, ...revenues, ...expenses],
    };
  }

  private paymentFunds(payment: SupabaseRow, allocations: SupabaseRow[]) {
    const direct = allocations.filter((row) => String(row.payment_id) === String(payment.id));
    const ofPayable = allocations.filter(
      (row) => !row.payment_id && String(row.payable_id) === String(payment.payable_id),
    );
    const allocatedTotal = ofPayable.reduce((sum, row) => sum + Number(row.amount), 0) || 1;
    const funds: Record<string, number> = {};
    for (const row of direct.length > 0 ? direct : ofPayable) {
      const share = direct.length > 0
        ? Number(row.amount)
        : (Number(row.amount) * Number(payment.amount)) / allocatedTotal;
      const code = String(row.revenue_type_code);
      funds[code] = round2((funds[code] ?? 0) + share);
    }
    return funds;
  }

  /** Contas não pagas (qualquer vencimento), com o valor que ainda falta. */
  private async pendingPayables(congregationId: string) {
    const payables = await this.db.query(
      'payables',
      `select=id,description,due_date,amount,category_id,notification_days_before&congregation_id=eq.${congregationId}&status=not.in.(PAID,CANCELLED)&order=due_date.asc`,
    );
    if (payables.length === 0) return [];
    const [payments, categories] = await Promise.all([
      this.db.query('payable_payments', `select=payable_id,amount&payable_id=in.(${payables.map((row) => String(row.id)).join(',')})`),
      this.db.query('expense_categories', `select=id,name&congregation_id=eq.${congregationId}`),
    ]);
    const categoryOf = new Map(categories.map((row) => [String(row.id), String(row.name)]));
    return payables.map((row) => {
      const paid = payments
        .filter((item) => String(item.payable_id) === String(row.id))
        .reduce((sum, item) => sum + Number(item.amount), 0);
      return {
        id: row.id,
        kind: 'PAYABLE',
        date: row.due_date,
        description: row.description,
        categoryId: row.category_id ?? null,
        category: categoryOf.get(String(row.category_id)) ?? null,
        notificationDaysBefore: row.notification_days_before,
        amount: Number(row.amount),
        remaining: round2(Number(row.amount) - paid),
      };
    });
  }

  // --------------------------------------------------------------- receitas

  async revenueCategories(congregationId: string) {
    const [categories, funds] = await Promise.all([
      this.db.query('revenue_categories', `select=id,code,name,entry_type_id&congregation_id=eq.${congregationId}&active=eq.true&order=name.asc`),
      this.db.query('entry_types', `select=id,code&congregation_id=eq.${congregationId}`),
    ]);
    const fundOf = new Map(funds.map((row) => [String(row.id), String(row.code)]));
    return categories.map((row) => ({
      id: row.id,
      code: row.code,
      name: row.name,
      fundCode: fundOf.get(String(row.entry_type_id)) ?? null,
    }));
  }

  /** Lança oferta ou dízimo com os valores em PIX e dinheiro (como na planilha). */
  async createRevenue(dto: CreateRevenueDto, authorization?: string) {
    const user = await this.db.authUser(authorization);
    const total = round2(dto.pixAmount + dto.cashAmount);
    if (total <= 0) throw new BadRequestException('Informe o valor recebido em PIX e/ou dinheiro.');
    await this.ensureDateInOpenCycle(dto.congregationId, dto.date);
    // Mesmo id = edição (ou reenvio da fila offline).
    const [existing] = await this.db.query('financial_entries', `select=*&id=eq.${dto.id}&limit=1`);
    if (existing) {
      if (existing.status !== 'CONFIRMED') {
        throw new BadRequestException('Este lançamento foi estornado e não pode ser editado.');
      }
      await this.ensureEditable(dto.congregationId, String(existing.entry_date));
    }
    const [fund] = await this.db.query(
      'entry_types',
      `select=id&congregation_id=eq.${dto.congregationId}&code=eq.${dto.fundCode}&limit=1`,
    );
    if (!fund) throw new BadRequestException('Fundo não cadastrado para esta congregação.');
    if (dto.categoryId) {
      const [category] = await this.db.query(
        'revenue_categories',
        `select=id&id=eq.${dto.categoryId}&entry_type_id=eq.${fund.id}&limit=1`,
      );
      if (!category) throw new BadRequestException('O tipo escolhido não pertence a este fundo.');
    }
    await this.db.mutate('financial_entries?on_conflict=id', 'POST', {
      id: dto.id,
      congregation_id: dto.congregationId,
      cycle_id: await this.technicalCycleId(dto.congregationId),
      entry_type_id: fund.id,
      revenue_category_id: dto.categoryId ?? null,
      entry_date: dto.date,
      description: dto.description.trim(),
      total_amount: total,
      status: 'CONFIRMED',
      created_by: user.id,
    }, 'resolution=merge-duplicates');
    await this.db.mutate(`financial_entry_lines?financial_entry_id=eq.${dto.id}`, 'DELETE');
    for (const [method, amount] of [['PIX', dto.pixAmount], ['CASH', dto.cashAmount]] as const) {
      if (amount > 0) {
        await this.db.mutate('financial_entry_lines', 'POST', {
          financial_entry_id: dto.id,
          payment_method: method,
          amount: round2(amount),
        });
      }
    }
    if (existing && (
      existing.entry_date !== dto.date ||
      Number(existing.total_amount) !== total ||
      existing.description !== dto.description.trim() ||
      (existing.revenue_category_id ?? null) !== (dto.categoryId ?? null)
    )) {
      await this.audit(dto.congregationId, user.id, 'UPDATE', 'financial_entry', dto.id, null, existing, {
        entry_date: dto.date, description: dto.description.trim(), total_amount: total,
        revenue_category_id: dto.categoryId ?? null, pix: dto.pixAmount, cash: dto.cashAmount,
      });
    }
    return { id: dto.id, amount: total };
  }

  // --------------------------------------------------------------- despesas

  async expenseCategories(congregationId: string) {
    return this.db.query(
      'expense_categories',
      `select=id,name&congregation_id=eq.${congregationId}&active=eq.true&order=name.asc`,
    );
  }

  /**
   * Lança uma despesa. Paga agora: grava conta, pagamento e o rateio por
   * fonte (soma deve ser igual ao valor). Conta a pagar: grava só a conta.
   */
  async createExpense(dto: CreateExpenseDto, authorization?: string) {
    const congregationId = dto.congregationId;
    const amount = round2(dto.amount);
    const [existing] = await this.db.query('payables', `select=*&id=eq.${dto.id}&limit=1`);
    if (existing) {
      if (existing.status === 'CANCELLED') {
        throw new BadRequestException('Esta despesa foi cancelada e não pode ser editada.');
      }
      const payments = await this.db.query('payable_payments', `select=id,payment_date&payable_id=eq.${dto.id}`);
      if (dto.status === 'PAYABLE' && payments.length > 0) {
        throw new BadRequestException('Conta com pagamento registrado não pode ser editada. Estorne o pagamento antes.');
      }
      for (const payment of payments) {
        await this.ensureEditable(congregationId, String(payment.payment_date));
      }
    }
    if (dto.status === 'PAID') {
      const error = validateFundingSources(amount, dto.fundingSources);
      if (error) throw new BadRequestException(error);
      await this.ensureDateInOpenCycle(congregationId, dto.paymentDate!);
    }
    const [category] = await this.db.query(
      'expense_categories',
      `select=id&id=eq.${dto.categoryId}&congregation_id=eq.${congregationId}&limit=1`,
    );
    if (!category) throw new BadRequestException('Categoria de despesa não encontrada.');
    const date = dto.status === 'PAID' ? dto.paymentDate! : dto.dueDate!;
    await this.db.mutate('payables?on_conflict=id', 'POST', {
      id: dto.id,
      congregation_id: congregationId,
      cycle_id: await this.technicalCycleId(congregationId),
      category_id: dto.categoryId,
      description: dto.description.trim(),
      issue_date: dto.status === 'PAID' ? date : payableIssueDate(date, todayInBrazil()),
      due_date: date,
      amount,
      status: dto.status === 'PAID' ? 'PAID' : 'OPEN',
      notification_days_before: dto.notificationDaysBefore ?? 3,
    }, 'resolution=merge-duplicates');
    if (dto.status === 'PAID') {
      const [existing] = await this.db.query('payable_payments', `select=id&payable_id=eq.${dto.id}&limit=1`);
      await this.savePayment({
        paymentId: existing ? String(existing.id) : randomUUID(),
        payableId: dto.id,
        congregationId,
        paymentDate: dto.paymentDate!,
        paymentMethod: dto.paymentMethod!,
        amount,
        fundingSources: dto.fundingSources ?? {},
      });
    }
    if (existing && (
      Number(existing.amount) !== amount ||
      existing.description !== dto.description.trim() ||
      existing.category_id !== dto.categoryId ||
      existing.due_date !== date
    )) {
      const actor = authorization ? (await this.db.authUser(authorization)).id : null;
      await this.audit(congregationId, actor, 'UPDATE', 'payable', dto.id, null, existing, {
        description: dto.description.trim(), category_id: dto.categoryId, amount, due_date: date,
        funding_sources: dto.fundingSources ?? null,
      });
    }
    return { id: dto.id, status: dto.status, amount };
  }

  // ---------------------------------------------------- estornos e cancelamento

  /** Estorna uma receita: sai dos totais, mas continua registrada com o motivo. */
  async reverseRevenue(entryId: string, dto: ReverseDto, authorization?: string) {
    const user = await this.db.authUser(authorization);
    const [entry] = await this.db.query(
      'financial_entries',
      `select=*&id=eq.${entryId}&congregation_id=eq.${dto.congregationId}&limit=1`,
    );
    if (!entry) throw new NotFoundException('Lançamento não encontrado.');
    if (entry.status === 'REVERSED') return { id: entryId, status: 'REVERSED' };
    await this.ensureEditable(dto.congregationId, String(entry.entry_date));
    await this.db.mutate(`financial_entries?id=eq.${entryId}`, 'PATCH', {
      status: 'REVERSED', updated_at: new Date().toISOString(),
    });
    await this.audit(dto.congregationId, user.id, 'REVERSE', 'financial_entry', entryId, dto.reason, entry, { status: 'REVERSED' });
    return { id: entryId, status: 'REVERSED' };
  }

  /**
   * Estorna um pagamento de despesa. `cancelExpense` cancela a despesa
   * inteira; senão a conta volta a ficar em aberto.
   */
  async reversePayment(paymentId: string, dto: ReverseDto, authorization?: string) {
    const user = await this.db.authUser(authorization);
    const [payment] = await this.db.query(
      'payable_payments',
      `select=*&id=eq.${paymentId}&congregation_id=eq.${dto.congregationId}&limit=1`,
    );
    // Já estornado (reenvio da fila offline): nada a fazer.
    if (!payment) return { paymentId, reversed: true };
    await this.ensureEditable(dto.congregationId, String(payment.payment_date));
    const allocations = await this.db.query('payable_funding_allocations', `select=*&payment_id=eq.${paymentId}`);
    await this.db.mutate(`payable_funding_allocations?payment_id=eq.${paymentId}`, 'DELETE');
    await this.db.mutate(`payable_payments?id=eq.${paymentId}`, 'DELETE');
    const payableId = String(payment.payable_id);
    const remainingPayments = await this.db.query('payable_payments', `select=amount&payable_id=eq.${payableId}`);
    const paid = remainingPayments.reduce((sum, row) => sum + Number(row.amount), 0);
    const status = dto.cancelExpense && paid === 0 ? 'CANCELLED' : paid > 0 ? 'PARTIALLY_PAID' : 'OPEN';
    await this.db.mutate(`payables?id=eq.${payableId}`, 'PATCH', { status });
    await this.audit(dto.congregationId, user.id, 'REVERSE', 'payable_payment', paymentId, dto.reason,
      { payment, allocations }, { payable_status: status });
    return { paymentId, reversed: true, payableStatus: status };
  }

  /** Cancela uma conta a pagar que ainda não teve pagamento. */
  async cancelPayable(payableId: string, dto: ReverseDto, authorization?: string) {
    const user = await this.db.authUser(authorization);
    const [payable] = await this.db.query(
      'payables',
      `select=*&id=eq.${payableId}&congregation_id=eq.${dto.congregationId}&limit=1`,
    );
    if (!payable) throw new NotFoundException('Conta a pagar não encontrada.');
    if (payable.status === 'CANCELLED') return { payableId, status: 'CANCELLED' };
    const payments = await this.db.query('payable_payments', `select=id&payable_id=eq.${payableId}&limit=1`);
    if (payments.length > 0) {
      throw new BadRequestException('A conta tem pagamento registrado. Estorne o pagamento antes de cancelar.');
    }
    await this.db.mutate(`payables?id=eq.${payableId}`, 'PATCH', { status: 'CANCELLED' });
    await this.audit(dto.congregationId, user.id, 'CANCEL', 'payable', payableId, dto.reason, payable, { status: 'CANCELLED' });
    return { payableId, status: 'CANCELLED' };
  }

  /** Paga (total ou parcialmente) uma conta a pagar, com as fontes do dinheiro. */
  async payPayable(payableId: string, dto: PayPayableDto) {
    const [payable] = await this.db.query(
      'payables',
      `select=id,amount,status&id=eq.${payableId}&congregation_id=eq.${dto.congregationId}&limit=1`,
    );
    if (!payable) throw new NotFoundException('Conta a pagar não encontrada.');
    const amount = round2(dto.amount);
    const error = validateFundingSources(amount, dto.fundingSources);
    if (error) throw new BadRequestException(error);
    await this.ensureDateInOpenCycle(dto.congregationId, dto.paymentDate);
    const payments = await this.db.query('payable_payments', `select=id,amount&payable_id=eq.${payableId}`);
    const alreadyPaid = payments
      .filter((row) => String(row.id) !== dto.paymentId)
      .reduce((sum, row) => sum + Number(row.amount), 0);
    const remaining = round2(Number(payable.amount) - alreadyPaid);
    if (amount > remaining + 0.001) {
      throw new BadRequestException(
        `O pagamento passa do valor em aberto (R$ ${remaining.toFixed(2).replace('.', ',')}).`,
      );
    }
    await this.savePayment({ ...dto, payableId, amount });
    const paidNow = round2(alreadyPaid + amount);
    await this.db.mutate(`payables?id=eq.${payableId}`, 'PATCH', {
      status: paidNow >= Number(payable.amount) - 0.001 ? 'PAID' : 'PARTIALLY_PAID',
    });
    return { payableId, paid: paidNow, remaining: round2(Number(payable.amount) - paidNow) };
  }

  private async savePayment(payment: {
    paymentId: string;
    payableId: string;
    congregationId: string;
    paymentDate: string;
    paymentMethod: string;
    amount: number;
    fundingSources: Record<string, number>;
  }) {
    await this.db.mutate('payable_payments?on_conflict=id', 'POST', {
      id: payment.paymentId,
      payable_id: payment.payableId,
      congregation_id: payment.congregationId,
      payment_date: payment.paymentDate,
      amount: payment.amount,
      payment_method: payment.paymentMethod,
    }, 'resolution=merge-duplicates');
    await this.db.mutate(`payable_funding_allocations?payment_id=eq.${payment.paymentId}`, 'DELETE');
    for (const [fund, value] of Object.entries(payment.fundingSources)) {
      if (Number(value) <= 0) continue;
      await this.db.mutate('payable_funding_allocations', 'POST', {
        payable_id: payment.payableId,
        payment_id: payment.paymentId,
        congregation_id: payment.congregationId,
        revenue_type_code: fund,
        amount: round2(Number(value)),
      });
    }
  }

  // -------------------------------------------------- tipos e categorias

  /** Cadastra tipo de receita (com `fundCode`) ou categoria de despesa. */
  async createCategory(kind: 'revenue' | 'expense', dto: CreateCategoryDto) {
    const id = dto.id ?? randomUUID();
    const name = dto.name.trim();
    if (kind === 'expense') {
      return this.db.mutateReturning('expense_categories?on_conflict=congregation_id,name', 'POST', {
        id, congregation_id: dto.congregationId, name: name.toUpperCase(), active: true,
      }, 'resolution=merge-duplicates,return=representation');
    }
    if (!dto.fundCode) throw new BadRequestException('Informe o fundo do tipo de receita.');
    const [fund] = await this.db.query(
      'entry_types',
      `select=id&congregation_id=eq.${dto.congregationId}&code=eq.${dto.fundCode}&limit=1`,
    );
    if (!fund) throw new BadRequestException('Fundo não cadastrado para esta congregação.');
    const code = name.normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/[^A-Z0-9]+/g, '_');
    return this.db.mutateReturning('revenue_categories?on_conflict=congregation_id,entry_type_id,code', 'POST', {
      id, congregation_id: dto.congregationId, entry_type_id: fund.id, code, name, active: true,
    }, 'resolution=merge-duplicates,return=representation');
  }

  // ---------------------------------------------------------------- apoio

  /** Lançamentos com data dentro de ciclo fechado não são aceitos. */
  private async ensureDateInOpenCycle(congregationId: string, date: string) {
    const closed = await this.db.query(
      'accountability_closures',
      `select=id&congregation_id=eq.${congregationId}&status=eq.CLOSED&period_start=lte.${date}&period_end=gte.${date}&limit=1`,
    );
    if (closed.length > 0) {
      throw new BadRequestException(
        `A data ${brDate(date)} pertence a um ciclo já fechado. Use uma data do ciclo atual.`,
      );
    }
  }

  /** Lançamento já registrado em ciclo fechado não pode ser alterado. */
  private async ensureEditable(congregationId: string, date: string) {
    const closed = await this.db.query(
      'accountability_closures',
      `select=id&congregation_id=eq.${congregationId}&status=eq.CLOSED&period_start=lte.${date}&period_end=gte.${date}&limit=1`,
    );
    if (closed.length > 0) {
      throw new BadRequestException(
        `Este lançamento (${brDate(date)}) pertence a um ciclo fechado e não pode ser alterado.`,
      );
    }
  }

  /** Registra quem alterou o quê, quando e por quê (tabela audit_events). */
  private async audit(
    congregationId: string,
    actorId: string | null,
    action: string,
    entityType: string,
    entityId: string,
    reason: string | null,
    before: unknown,
    after: unknown,
  ) {
    const [congregation] = await this.db.query(
      'congregations',
      `select=organization_id&id=eq.${congregationId}&limit=1`,
    );
    await this.db.mutate('audit_events', 'POST', {
      organization_id: congregation?.organization_id,
      congregation_id: congregationId,
      actor_id: actorId,
      action,
      entity_type: entityType,
      entity_id: entityId,
      reason,
      before_data: before as SupabaseRow,
      after_data: after as SupabaseRow,
    });
  }

  /** `cycle_id` ainda é obrigatório no esquema; usa o ciclo técnico da congregação. */
  private async technicalCycleId(congregationId: string) {
    const [cycle] = await this.db.query(
      'accountability_cycles',
      `select=id&congregation_id=eq.${congregationId}&order=created_at.asc&limit=1`,
    );
    if (!cycle) throw new ServiceUnavailableException('Congregação sem ciclo técnico cadastrado.');
    return cycle.id;
  }
}
