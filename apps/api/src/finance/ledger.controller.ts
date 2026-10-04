import { Body, Controller, Get, Headers, Param, Post, Query } from '@nestjs/common';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { CreateRevenueDto } from './dto/create-revenue.dto';
import { PayPayableDto } from './dto/pay-payable.dto';
import { LedgerService } from './ledger.service';

/** Lançamentos da tesouraria (extrato, receitas, despesas, pagamentos). */
@Controller('finance')
export class LedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Get('ledger')
  getLedger(
    @Query('congregationId') congregationId: string,
    @Query('cycleId') cycleId?: string,
  ) {
    return this.ledger.ledger(congregationId, cycleId);
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
  createExpense(@Body() dto: CreateExpenseDto) {
    return this.ledger.createExpense(dto);
  }

  @Post('payables/:payableId/pay')
  payPayable(@Param('payableId') payableId: string, @Body() dto: PayPayableDto) {
    return this.ledger.payPayable(payableId, dto);
  }
}
