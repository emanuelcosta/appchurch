import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { CreateClosureDto } from './dto/create-closure.dto';
import { CloseClosureDto } from './dto/close-closure.dto';
import { CreateMemberDto } from './dto/create-member.dto';
import { carryOverBalances, nextDay, round2, summarizeCycle } from './cycle-summary';

import { SupabaseRestService, SupabaseRow } from './supabase-rest.service';
const MEMBER_COLUMNS = [
  'id', 'full_name', 'birth_date', 'rg', 'cpf', 'marital_status', 'mother_name',
  'father_name', 'spouse_name', 'address', 'nationality', 'birthplace',
  'ministry_role', 'ministry_role_since', 'holy_spirit_baptism',
  'holy_spirit_baptism_date', 'education', 'children_count', 'phone', 'email',
].join(',');
const PAID_STATUSES = ['PAID', 'PARTIALLY_PAID'];

@Injectable()
export class SupabaseDashboardService {
  constructor(private readonly db: SupabaseRestService) {}

  /**
   * Dashboard no formato da planilha: um ciclo de prestação de contas por vez.
   * Sem `cycleId`, usa o ciclo aberto (ou o mais recente).
   */
  async dashboard(congregationId: string, cycleId?: string) {
    const closures = await this.closureRows(congregationId);
    const cycles = closures.map((row) => this.toCycle(row));
    const selected =
      closures.find((row) => String(row.id) === cycleId) ??
      closures.find((row) => row.status === 'OPEN') ??
      closures[0];
    const pendingPayables = await this.pendingPayables(congregationId);
    if (!selected) {
      return { congregationId, cycles, cycle: null, pendingPayables };
    }
    const summary = await this.cycleSummary(congregationId, selected, closures);
    return {
      congregationId,
      cycles,
      cycle: this.toCycle(selected),
      ...summary,
      pendingPayables,
    };
  }

  /**
   * Lançamentos do ciclo para consulta: receitas (ofertas e dízimos) e
   * despesas pagas, com a origem do dinheiro de cada pagamento.
   */
  async transactions(congregationId: string, cycleId?: string) {
    const closures = await this.closureRows(congregationId);
    const selected =
      closures.find((row) => String(row.id) === cycleId) ??
      closures.find((row) => row.status === 'OPEN') ??
      closures[0];
    const cycles = closures.map((row) => this.toCycle(row));
    if (!selected) return { cycles, cycle: null, entries: [], expenses: [] };
    const start = String(selected.period_start);
    const end = selected.status === 'OPEN' ? undefined : String(selected.period_end);
    const entryRange = `entry_date=gte.${start}${end ? `&entry_date=lte.${end}` : ''}`;
    const paymentRange = `payment_date=gte.${start}${end ? `&payment_date=lte.${end}` : ''}`;
    const [entries, types, categories, payments, payables, expenseCategories, allocations] = await Promise.all([
      this.db.query('financial_entries', `select=id,entry_date,description,total_amount,entry_type_id,revenue_category_id&congregation_id=eq.${congregationId}&status=eq.CONFIRMED&${entryRange}&order=entry_date.desc`),
      this.db.query('entry_types', `select=id,code&congregation_id=eq.${congregationId}`),
      this.db.query('revenue_categories', `select=id,name&congregation_id=eq.${congregationId}`),
      this.db.query('payable_payments', `select=id,payable_id,payment_date,amount,payment_method&congregation_id=eq.${congregationId}&${paymentRange}&order=payment_date.desc`),
      this.db.query('payables', `select=id,description,category_id&congregation_id=eq.${congregationId}`),
      this.db.query('expense_categories', `select=id,name&congregation_id=eq.${congregationId}`),
      this.db.query('payable_funding_allocations', `select=payable_id,payment_id,revenue_type_code,amount&congregation_id=eq.${congregationId}`),
    ]);
    const fundOf = new Map(types.map((row) => [String(row.id), String(row.code)]));
    const revenueCategoryOf = new Map(categories.map((row) => [String(row.id), String(row.name)]));
    const payableOf = new Map(payables.map((row) => [String(row.id), row]));
    const expenseCategoryOf = new Map(expenseCategories.map((row) => [String(row.id), String(row.name)]));
    return {
      cycles,
      cycle: this.toCycle(selected),
      entries: entries.map((row) => ({
        id: row.id,
        date: row.entry_date,
        description: row.description,
        fundCode: fundOf.get(String(row.entry_type_id)) ?? 'OUTROS',
        category: revenueCategoryOf.get(String(row.revenue_category_id)) ?? null,
        amount: Number(row.total_amount),
      })),
      expenses: payments.map((payment) => {
        const payable = payableOf.get(String(payment.payable_id));
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
        return {
          id: payment.id,
          date: payment.payment_date,
          description: payable?.description ?? 'Despesa',
          category: expenseCategoryOf.get(String(payable?.category_id)) ?? null,
          paymentMethod: payment.payment_method,
          amount: Number(payment.amount),
          funds,
        };
      }),
    };
  }

  async listCycles(congregationId: string) {
    return (await this.closureRows(congregationId)).map((row) => this.toCycle(row));
  }

  private async closureRows(congregationId: string) {
    return this.db.query(
      'accountability_closures',
      `select=id,period_start,period_end,status,notes&congregation_id=eq.${congregationId}&status=neq.CANCELLED&order=period_start.desc`,
    );
  }

  private toCycle(row: SupabaseRow) {
    return {
      id: row.id,
      startDate: row.period_start,
      endDate: row.period_end,
      status: row.status,
    };
  }

  /**
   * Ciclo fechado: usa a foto gravada no fechamento.
   * Ciclo aberto (ou prévia de fechamento): calcula ao vivo a partir dos lançamentos,
   * com saldo anterior = saldo final do ciclo fechado anterior menos os repasses.
   */
  private async cycleSummary(
    congregationId: string,
    closure: SupabaseRow,
    closures: SupabaseRow[],
    endDateOverride?: string,
  ) {
    const startDate = String(closure.period_start);
    const isClosed = closure.status === 'CLOSED' && !endDateOverride;
    const endDate = endDateOverride ?? (isClosed ? String(closure.period_end) : undefined);
    const revenue = await this.revenueByFund(congregationId, startDate, endDate);

    if (isClosed) {
      const [balances, allocations] = await Promise.all([
        this.db.query('accountability_closure_balances', `select=fund_code,opening_balance,revenue_total,expense_total,closing_balance&closure_id=eq.${closure.id}`),
        this.db.query('accountability_closure_allocations', `select=id,fund_code,sequence,percentage,amount,destination_code,destination_name&closure_id=eq.${closure.id}&order=sequence.asc`),
      ]);
      const pick = (column: string) =>
        Object.fromEntries(balances.map((row) => [String(row.fund_code), Number(row[column])]));
      const leader = allocations.find((row) => row.destination_code === 'DIRIGENTE');
      const summary = summarizeCycle({
        opening: pick('opening_balance'),
        revenueByFund: pick('revenue_total'),
        expensesByFund: pick('expense_total'),
        leaderPercentage: Number(leader?.percentage ?? 0),
      });
      return {
        ...summary,
        revenueByCategory: revenue.byCategory,
        titheEntries: revenue.titheEntries,
        transfers: await this.transfersOf(allocations),
      };
    }

    const previous = closures.find(
      (row) => row.status === 'CLOSED' && String(row.period_end) < startDate,
    );
    const [opening, expensesByFund, leaderPercentage] = await Promise.all([
      previous ? this.carryOver(previous) : Promise.resolve({}),
      this.expensesByFund(congregationId, startDate, endDate),
      this.leaderPercentage(congregationId),
    ]);
    const summary = summarizeCycle({
      opening,
      revenueByFund: revenue.byFund,
      expensesByFund,
      leaderPercentage,
    });
    return {
      ...summary,
      revenueByCategory: revenue.byCategory,
      titheEntries: revenue.titheEntries,
      transfers: [
        { destinationCode: 'DIRIGENTE', destinationName: 'Dirigente', fundCode: 'DIZIMOS', amount: summary.tithe.leaderAmount, status: 'PREVISTO' },
        { destinationCode: 'SEDE', destinationName: 'Igreja sede', fundCode: 'DIZIMOS', amount: summary.tithe.headquartersAmount, status: 'PREVISTO' },
      ],
    };
  }

  private async carryOver(closure: SupabaseRow) {
    const [balances, allocations] = await Promise.all([
      this.db.query('accountability_closure_balances', `select=fund_code,closing_balance&closure_id=eq.${closure.id}`),
      this.db.query('accountability_closure_allocations', `select=fund_code,amount&closure_id=eq.${closure.id}`),
    ]);
    const closing: Record<string, number> = {};
    for (const row of balances) closing[String(row.fund_code)] = Number(row.closing_balance);
    const transferred: Record<string, number> = {};
    for (const row of allocations) {
      const fund = String(row.fund_code);
      transferred[fund] = (transferred[fund] ?? 0) + Number(row.amount);
    }
    return carryOverBalances(closing, transferred);
  }

  private async transfersOf(allocations: SupabaseRow[]) {
    if (allocations.length === 0) return [];
    const paid = await this.db.query(
      'accountability_closure_transfers',
      `select=allocation_id,amount,status,transfer_date&allocation_id=in.(${allocations.map((row) => String(row.id)).join(',')})`,
    );
    return allocations.map((row) => {
      const done = paid.filter((item) => String(item.allocation_id) === String(row.id) && item.status === 'PAID');
      return {
        destinationCode: row.destination_code,
        destinationName: row.destination_name,
        fundCode: row.fund_code,
        amount: Number(row.amount),
        status: done.length > 0 ? 'PAGO' : 'A_PAGAR',
      };
    });
  }

  private async revenueByFund(congregationId: string, startDate: string, endDate?: string) {
    const range = `entry_date=gte.${startDate}${endDate ? `&entry_date=lte.${endDate}` : ''}`;
    const [entries, types, categories] = await Promise.all([
      this.db.query('financial_entries', `select=entry_date,description,total_amount,entry_type_id,revenue_category_id&congregation_id=eq.${congregationId}&status=eq.CONFIRMED&${range}&order=entry_date.asc`),
      this.db.query('entry_types', `select=id,code&congregation_id=eq.${congregationId}`),
      this.db.query('revenue_categories', `select=id,name&congregation_id=eq.${congregationId}`),
    ]);
    const fundOf = new Map(types.map((row) => [String(row.id), String(row.code)]));
    const categoryOf = new Map(categories.map((row) => [String(row.id), String(row.name)]));
    const byFund: Record<string, number> = {};
    const byCategory = new Map<string, { fundCode: string; category: string; amount: number }>();
    // Dízimos listados por contribuinte, como no relatório mensal da planilha.
    const titheEntries: { date: unknown; name: unknown; amount: number }[] = [];
    for (const entry of entries) {
      const fund = fundOf.get(String(entry.entry_type_id)) ?? 'OUTROS';
      const category = categoryOf.get(String(entry.revenue_category_id)) ?? 'Sem tipo';
      const amount = Number(entry.total_amount);
      byFund[fund] = (byFund[fund] ?? 0) + amount;
      if (fund === 'DIZIMOS') {
        titheEntries.push({ date: entry.entry_date, name: entry.description, amount });
      }
      const key = `${fund}|${category}`;
      const current = byCategory.get(key) ?? { fundCode: fund, category, amount: 0 };
      current.amount = round2(current.amount + amount);
      byCategory.set(key, current);
    }
    return { byFund, byCategory: [...byCategory.values()], titheEntries };
  }

  /** Despesas pagas no período, separadas pela origem do dinheiro (rateio). */
  private async expensesByFund(congregationId: string, startDate: string, endDate?: string) {
    const range = `payment_date=gte.${startDate}${endDate ? `&payment_date=lte.${endDate}` : ''}`;
    const [payments, allocations] = await Promise.all([
      this.db.query('payable_payments', `select=id,payable_id,amount&congregation_id=eq.${congregationId}&${range}`),
      this.db.query('payable_funding_allocations', `select=payable_id,payment_id,revenue_type_code,amount&congregation_id=eq.${congregationId}`),
    ]);
    const result: Record<string, number> = {};
    for (const payment of payments) {
      const direct = allocations.filter((row) => String(row.payment_id) === String(payment.id));
      const ofPayable = allocations.filter(
        (row) => !row.payment_id && String(row.payable_id) === String(payment.payable_id),
      );
      // Rateio por pagamento quando existir; senão, o pagamento segue a proporção
      // do rateio da conta (o total do rateio pode diferir do valor da conta).
      const allocatedTotal = ofPayable.reduce((sum, row) => sum + Number(row.amount), 0) || 1;
      const shares = direct.length > 0
        ? direct.map((row) => ({ fund: String(row.revenue_type_code), amount: Number(row.amount) }))
        : ofPayable.map((row) => ({
            fund: String(row.revenue_type_code),
            amount: (Number(row.amount) * Number(payment.amount)) / allocatedTotal,
          }));
      for (const share of shares) {
        result[share.fund] = (result[share.fund] ?? 0) + share.amount;
      }
    }
    return result;
  }

  private async leaderPercentage(congregationId: string) {
    const rules = await this.db.queryOptional(
      'distribution_rules',
      `select=percentage&congregation_id=eq.${congregationId}&fund_code=eq.DIZIMOS&destination_code=eq.DIRIGENTE&active=eq.true&limit=1`,
    );
    if (rules[0]?.percentage != null) return Number(rules[0].percentage);
    const settings = await this.db.queryOptional('tithe_distribution_settings', `select=leader_percentage&congregation_id=eq.${congregationId}`);
    return Number(settings[0]?.leader_percentage ?? 20);
  }

  /** Contas não pagas que vencem até o fim do mês seguinte (inclui atrasadas). */
  private async pendingPayables(congregationId: string) {
    const today = new Date();
    const limit = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() + 2, 0)).toISOString().slice(0, 10);
    const todayIso = today.toISOString().slice(0, 10);
    const payables = await this.db.query(
      'payables',
      `select=id,description,due_date,amount,status&congregation_id=eq.${congregationId}&status=not.in.(PAID,CANCELLED)&due_date=lte.${limit}&order=due_date.asc`,
    );
    if (payables.length === 0) return [];
    const payments = await this.db.query(
      'payable_payments',
      `select=payable_id,amount&payable_id=in.(${payables.map((row) => String(row.id)).join(',')})`,
    );
    return payables.map((row) => {
      const paid = payments
        .filter((item) => String(item.payable_id) === String(row.id))
        .reduce((sum, item) => sum + Number(item.amount), 0);
      return {
        id: row.id,
        description: row.description,
        dueDate: row.due_date,
        amount: Number(row.amount),
        remaining: round2(Number(row.amount) - paid),
        overdue: String(row.due_date) < todayIso,
      };
    });
  }

  async monthlyReport(congregationId: string, startDate: string, endDate: string) {
    const [entries, previousEntries, types, payables, payments, previousPayments, allocations, settings, closures] = await Promise.all([
      this.db.query('financial_entries', `select=entry_date,total_amount,entry_type_id,status&congregation_id=eq.${congregationId}&status=eq.CONFIRMED&entry_date=gte.${startDate}&entry_date=lte.${endDate}`),
      this.db.query('financial_entries', `select=total_amount,entry_type_id&congregation_id=eq.${congregationId}&status=eq.CONFIRMED&entry_date=lt.${startDate}`),
      this.db.query('entry_types', `select=id,code&congregation_id=eq.${congregationId}`),
      this.db.query('payables', `select=id,amount,status&congregation_id=eq.${congregationId}`),
      this.db.query('payable_payments', `select=payable_id,payment_date,amount&congregation_id=eq.${congregationId}&payment_date=gte.${startDate}&payment_date=lte.${endDate}`),
      this.db.query('payable_payments', `select=payable_id,amount&congregation_id=eq.${congregationId}&payment_date=lt.${startDate}`),
      this.db.query('payable_funding_allocations', `select=payable_id,revenue_type_code,amount&congregation_id=eq.${congregationId}`),
      this.db.queryOptional('tithe_distribution_settings', `select=leader_percentage&congregation_id=eq.${congregationId}`),
      this.db.queryOptional('accountability_closures', `select=id&period_start&period_end&congregation_id=eq.${congregationId}&period_start=eq.${startDate}&period_end=eq.${endDate}&limit=1`),
    ]);
    const typeMap = new Map(types.map((type) => [String(type.id), String(type.code)]));
    const byType: Record<string, number> = {};
    const openingByType: Record<string, number> = {};
    for (const entry of entries) {
      const code = typeMap.get(String(entry.entry_type_id)) ?? 'OUTROS';
      byType[code] = (byType[code] ?? 0) + Number(entry.total_amount);
    }
    for (const entry of previousEntries) {
      const code = typeMap.get(String(entry.entry_type_id)) ?? 'OUTROS';
      openingByType[code] = (openingByType[code] ?? 0) + Number(entry.total_amount);
    }
    const payableMap = new Map(payables.map((payable) => [String(payable.id), payable]));
    const expensesByType: Record<string, number> = {};
    for (const payment of payments) {
      const payable = payableMap.get(String(payment.payable_id));
      const payableAmount = Number(payable?.amount ?? 0);
      if (!payableAmount) continue;
      const ratio = Number(payment.amount) / payableAmount;
      for (const allocation of allocations.filter((item) => String(item.payable_id) === String(payment.payable_id))) {
        const code = String(allocation.revenue_type_code);
        expensesByType[code] = (expensesByType[code] ?? 0) + Number(allocation.amount) * ratio;
      }
    }
    const grossTithes = byType.DIZIMOS ?? 0;
    const paidTitheExpenses = expensesByType.DIZIMOS ?? 0;
    const leaderPercentage = Number(settings[0]?.leader_percentage ?? 20);
    const leaderAmount = grossTithes * leaderPercentage / 100;
    const pendingTotal = payables
      .filter((payable) => !['PAID', 'CANCELLED'].includes(String(payable.status)))
      .reduce((sum, payable) => sum + Number(payable.amount), 0);
    const previousExpensesByType: Record<string, number> = {};
    for (const payment of previousPayments) {
      const payable = payableMap.get(String(payment.payable_id));
      const payableAmount = Number(payable?.amount ?? 0);
      if (!payableAmount) continue;
      const ratio = Number(payment.amount) / payableAmount;
      for (const allocation of allocations.filter((item) => String(item.payable_id) === String(payment.payable_id))) {
        const code = String(allocation.revenue_type_code);
        previousExpensesByType[code] = (previousExpensesByType[code] ?? 0) + Number(allocation.amount) * ratio;
      }
    }
    const closingByType: Record<string, number> = {};
    for (const code of new Set([...Object.keys(openingByType), ...Object.keys(byType), ...Object.keys(expensesByType), ...Object.keys(previousExpensesByType)])) {
      closingByType[code] = (openingByType[code] ?? 0) + (byType[code] ?? 0)
        - (previousExpensesByType[code] ?? 0) - (expensesByType[code] ?? 0);
    }
    const closure = closures[0];
    if (closure) {
      const balances = await this.db.queryOptional(
        'accountability_closure_balances',
        `select=fund_code,opening_balance,revenue_total,expense_total,closing_balance&closure_id=eq.${closure.id}`,
      );
      for (const balance of balances) {
        const code = String(balance.fund_code);
        openingByType[code] = Number(balance.opening_balance);
        closingByType[code] = Number(balance.closing_balance);
        byType[code] = Number(balance.revenue_total);
        expensesByType[code] = Number(balance.expense_total);
      }
    }
    return {
      period: { startDate, endDate },
      openingByType,
      byType,
      expensesByType,
      closingByType,
      pendingTotal,
      tithe: {
        gross: grossTithes,
        leaderPercentage,
        leaderAmount,
        paidExpenses: paidTitheExpenses,
        headquartersAmount: grossTithes - leaderAmount - paidTitheExpenses,
        remainingAfterExpenses: grossTithes - paidTitheExpenses,
      },
    };
  }

  async titheDistribution(congregationId: string) {
    const today = new Date();
    const start = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 1)).toISOString().slice(0, 10);
    const end = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() + 1, 0)).toISOString().slice(0, 10);
    return this.monthlyReport(congregationId, start, end).then((report) => report.tithe);
  }

  async setTitheDistribution(congregationId: string, leaderPercentage: number) {
    await this.db.mutate('tithe_distribution_settings?on_conflict=congregation_id', 'POST', {
      congregation_id: congregationId,
      leader_percentage: leaderPercentage,
    }, 'resolution=merge-duplicates');
    return this.titheDistribution(congregationId);
  }

  async createClosure(dto: CreateClosureDto) {
    const open = await this.db.queryOptional(
      'accountability_closures',
      `select=id&congregation_id=eq.${dto.congregationId}&status=in.(OPEN,IN_REVIEW,PENDING_APPROVAL,APPROVED)&limit=1`,
    );
    if (open.length > 0) {
      throw new ServiceUnavailableException('Já existe uma prestação de contas aberta para esta congregação.');
    }
    return this.db.mutateReturning('accountability_closures', 'POST', {
      id: randomUUID(),
      congregation_id: dto.congregationId,
      period_start: dto.periodStart,
      status: 'OPEN',
      notes: dto.notes ?? null,
    }, 'return=representation');
  }

  async listClosures(congregationId: string) {
    return this.db.query(
      'accountability_closures',
      `select=id,period_start,period_end,status,notes,created_at,closed_at&congregation_id=eq.${congregationId}&order=period_start.desc`,
    );
  }

  async previewClosure(closureId: string, endDate?: string) {
    const closure = await this.closureById(closureId);
    const reportEnd = endDate ?? String(closure.period_end ?? new Date().toISOString().slice(0, 10));
    if (reportEnd < String(closure.period_start)) {
      throw new BadRequestException('A data final não pode ser anterior à data inicial.');
    }
    const congregationId = String(closure.congregation_id);
    const closures = await this.closureRows(congregationId);
    return {
      cycle: { ...this.toCycle(closure), endDate: reportEnd },
      ...(await this.cycleSummary(congregationId, closure, closures, reportEnd)),
    };
  }

  /**
   * Fecha o ciclo aberto: grava a foto dos saldos e os repasses de dízimos
   * (saídas do tipo REPASSE) e abre o próximo ciclo no dia seguinte.
   */
  async closeClosure(closureId: string, dto: CloseClosureDto) {
    const closure = await this.closureById(closureId);
    if (closure.status !== 'OPEN') {
      throw new BadRequestException('Somente o ciclo aberto pode ser fechado.');
    }
    const preview = await this.previewClosure(closureId, dto.periodEnd);
    const { funds, tithe } = preview;
    if (tithe.headquartersNegative) {
      throw new BadRequestException(
        'As despesas pagas com dízimos superam o valor disponível para a sede. Revise o ciclo antes de fechar.',
      );
    }
    const congregationId = String(closure.congregation_id);
    for (const [fundCode, fund] of Object.entries(funds)) {
      await this.db.mutate('accountability_closure_balances?on_conflict=closure_id,fund_code', 'POST', {
        closure_id: closureId,
        congregation_id: congregationId,
        fund_code: fundCode,
        opening_balance: fund.opening,
        revenue_total: fund.revenue,
        expense_total: fund.expenses,
        closing_balance: fund.closing,
      }, 'resolution=merge-duplicates');
    }
    await this.db.mutate(`accountability_closure_allocations?closure_id=eq.${closureId}`, 'DELETE');
    for (const allocation of [
      { sequence: 1, baseType: 'GROSS_REVENUE', baseAmount: tithe.gross, percentage: tithe.leaderPercentage, amount: tithe.leaderAmount, destinationCode: 'DIRIGENTE', destinationName: 'Dirigente' },
      { sequence: 2, baseType: 'BALANCE_AFTER_EXPENSES', baseAmount: tithe.balanceBeforeTransfers, percentage: 100 - tithe.leaderPercentage, amount: tithe.headquartersAmount, destinationCode: 'SEDE', destinationName: 'Igreja sede' },
    ]) {
      await this.db.mutate('accountability_closure_allocations', 'POST', {
        closure_id: closureId,
        congregation_id: congregationId,
        fund_code: 'DIZIMOS',
        sequence: allocation.sequence,
        base_type: allocation.baseType,
        base_amount: allocation.baseAmount,
        percentage: allocation.percentage,
        amount: allocation.amount,
        destination_code: allocation.destinationCode,
        destination_name: allocation.destinationName,
      });
    }
    await this.db.mutate(`accountability_closures?id=eq.${closureId}`, 'PATCH', {
      period_end: dto.periodEnd,
      status: 'CLOSED',
      notes: dto.notes ?? null,
      closed_at: new Date().toISOString(),
    }, 'return=minimal');
    const next = await this.db.mutateReturning('accountability_closures', 'POST', {
      id: randomUUID(),
      congregation_id: congregationId,
      period_start: nextDay(dto.periodEnd),
      status: 'OPEN',
      notes: 'Ciclo aberto automaticamente após o fechamento anterior.',
    }, 'return=representation');
    return { closed: preview, nextCycle: this.toCycle(next) };
  }

  private async closureById(closureId: string) {
    const closure = (await this.db.query(
      'accountability_closures',
      `select=id,congregation_id,period_start,period_end,status,notes&id=eq.${closureId}&limit=1`,
    ))[0];
    if (!closure) throw new NotFoundException('Ciclo de prestação de contas não encontrado.');
    return closure;
  }

  async members(congregationId: string) {
    return this.db.query('congregation_members', `select=${MEMBER_COLUMNS}&congregation_id=eq.${congregationId}&order=full_name.asc`);
  }

  /**
   * Cadastra ou edita um membro (mesmo `id` = edição; idempotente para a
   * fila offline). Na edição, preserva a origem do cadastro (`import_key`).
   */
  async createMember(dto: CreateMemberDto) {
    const id = dto.id ?? randomUUID();
    const text = (value?: string) => value?.trim() || null;
    const fields = {
      full_name: dto.fullName.trim(),
      birth_date: dto.birthDate ?? null,
      rg: text(dto.rg),
      cpf: text(dto.cpf),
      marital_status: text(dto.maritalStatus),
      mother_name: text(dto.motherName),
      father_name: text(dto.fatherName),
      spouse_name: text(dto.spouseName),
      address: text(dto.address),
      nationality: text(dto.nationality),
      birthplace: text(dto.birthplace),
      ministry_role: text(dto.ministryRole)?.toUpperCase() ?? null,
      ministry_role_since: dto.ministryRoleSince ?? null,
      holy_spirit_baptism: dto.holySpiritBaptism ?? null,
      holy_spirit_baptism_date: dto.holySpiritBaptismDate ?? null,
      education: text(dto.education),
      children_count: dto.childrenCount ?? null,
      phone: text(dto.phone),
      email: text(dto.email),
    };
    const [existing] = await this.db.query(
      'congregation_members',
      `select=id&id=eq.${id}&congregation_id=eq.${dto.congregationId}&limit=1`,
    );
    if (existing) {
      return this.db.mutateReturning(`congregation_members?id=eq.${id}`, 'PATCH', {
        ...fields,
        updated_at: new Date().toISOString(),
      }, 'return=representation');
    }
    return this.db.mutateReturning('congregation_members', 'POST', {
      id,
      congregation_id: dto.congregationId,
      ...fields,
      import_key: `app-${id}`,
    }, 'return=representation');
  }

  /** Perfil do usuário autenticado: valida o token no Supabase Auth. */
  async me(authorization?: string) {
    const user = await this.db.authUser(authorization);
    const [profiles, memberships] = await Promise.all([
      this.db.query('profiles', `select=full_name,email&id=eq.${user.id}&limit=1`),
      this.db.query('memberships', `select=role_code,congregation_id&user_id=eq.${user.id}&active=eq.true`),
    ]);
    const congregationIds = [...new Set(memberships.map((row) => String(row.congregation_id)))];
    const congregations = congregationIds.length
      ? await this.db.query('congregations', `select=id,name&id=in.(${congregationIds.join(',')})`)
      : [];
    const nameOf = new Map(congregations.map((row) => [String(row.id), String(row.name)]));
    return {
      userId: user.id,
      fullName: profiles[0]?.full_name ?? null,
      email: profiles[0]?.email ?? user.email ?? null,
      memberships: memberships.map((row) => ({
        congregationId: row.congregation_id,
        congregationName: nameOf.get(String(row.congregation_id)) ?? null,
        role: row.role_code,
      })),
    };
  }

  async history(congregationId: string) {
    const [entries, types, payables, allocations] = await Promise.all([
      this.db.query('financial_entries', `select=id,entry_date,description,total_amount,entry_type_id&congregation_id=eq.${congregationId}&order=entry_date.desc`),
      this.db.query('entry_types', `select=id,code,name&congregation_id=eq.${congregationId}`),
      this.db.query('payables', `select=id,issue_date,description,amount,status&congregation_id=eq.${congregationId}&order=issue_date.desc`),
      this.db.query('payable_funding_allocations', `select=payable_id,revenue_type_code,amount&congregation_id=eq.${congregationId}`),
    ]);
    const typeMap = new Map(types.map((type) => [String(type.id), { code: String(type.code), name: String(type.name) }]));
    return {
      entries: entries.map((entry) => ({ id: entry.id, date: entry.entry_date, description: entry.description, amount: Number(entry.total_amount), type: typeMap.get(String(entry.entry_type_id)) ?? { code: 'OUTROS', name: 'Outros' } })),
      payables: payables.map((payable) => ({
        id: payable.id, date: payable.issue_date, description: payable.description, amount: Number(payable.amount), status: payable.status,
        allocations: allocations.filter((item) => String(item.payable_id) === String(payable.id)).map((item) => ({ type: item.revenue_type_code, amount: Number(item.amount) })),
      })),
    };
  }
}
