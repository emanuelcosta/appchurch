import { Body, Controller, Get, Headers, Param, Post, Query } from '@nestjs/common';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { CreateRevenueDto } from './dto/create-revenue.dto';
import { PayPayableDto } from './dto/pay-payable.dto';
import { ReverseDto } from './dto/reverse.dto';
import { LedgerService } from './ledger.service';

/** Lançamentos da tesouraria (extrato, receitas, despesas, pagamentos). */
@Controller('finance')
export class LedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Get('ledger')
  getLedger(
    @Query('congregationId') congregationId: string,
    @Query('cycleId') cycleId?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.ledger.ledger(congregationId, cycleId, from && to ? { from, to } : undefined);
  }

  @Post('revenues')
  createRevenue(
    @Body() dto: CreateRevenueDto,
    @Headers('authorization') authorization?: string,
  ) {
    return this.ledger.createRevenue(dto, authorization);
  }

  @Get('revenue-categories')
  listRevenueCategories(@Query('congregationId') congregationId: string) {
    return this.ledger.revenueCategories(congregationId);
  }

  @Post('revenue-categories')
  createRevenueCategory(@Body() dto: CreateCategoryDto) {
    return this.ledger.createCategory('revenue', dto);
  }

  @Get('expense-categories')
  listExpenseCategories(@Query('congregationId') congregationId: string) {
    return this.ledger.expenseCategories(congregationId);
  }

  @Post('expense-categories')
  createExpenseCategory(@Body() dto: CreateCategoryDto) {
    return this.ledger.createCategory('expense', dto);
  }

  @Post('expenses')
  createExpense(
    @Body() dto: CreateExpenseDto,
    @Headers('authorization') authorization?: string,
  ) {
    return this.ledger.createExpense(dto, authorization);
  }

  @Post('revenues/:entryId/reverse')
  reverseRevenue(
    @Param('entryId') entryId: string,
    @Body() dto: ReverseDto,
    @Headers('authorization') authorization?: string,
  ) {
    return this.ledger.reverseRevenue(entryId, dto, authorization);
  }

  @Post('payments/:paymentId/reverse')
  reversePayment(
    @Param('paymentId') paymentId: string,
    @Body() dto: ReverseDto,
    @Headers('authorization') authorization?: string,
  ) {
    return this.ledger.reversePayment(paymentId, dto, authorization);
  }

  @Post('payables/:payableId/cancel')
  cancelPayable(
    @Param('payableId') payableId: string,
    @Body() dto: ReverseDto,
    @Headers('authorization') authorization?: string,
  ) {
    return this.ledger.cancelPayable(payableId, dto, authorization);
  }

  @Post('payables/:payableId/pay')
  payPayable(@Param('payableId') payableId: string, @Body() dto: PayPayableDto) {
    return this.ledger.payPayable(payableId, dto);
  }
}
