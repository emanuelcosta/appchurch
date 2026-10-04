import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { CreateCycleDto } from './dto/create-cycle.dto';
import { CreateEntryDto } from './dto/create-entry.dto';
import { CreatePayableDto } from './dto/create-payable.dto';
import { SetNotificationDaysDto } from './dto/set-notification-days.dto';
import { CreatePayablePaymentDto } from './dto/create-payable-payment.dto';
import { FinanceService } from './finance.service';
import { SupabaseDashboardService } from './supabase-dashboard.service';
import { SetTitheDistributionDto } from './dto/set-tithe-distribution.dto';
import { CreateClosureDto } from './dto/create-closure.dto';
import { CloseClosureDto } from './dto/close-closure.dto';
import { CreateMemberDto } from './dto/create-member.dto';

@Controller('finance')
export class FinanceController {
  constructor(
    private readonly financeService: FinanceService,
    private readonly dashboardService: SupabaseDashboardService,
  ) {}

  @Get('dashboard')
  getDashboard(
    @Query('congregationId') congregationId: string,
    @Query('cycleId') cycleId?: string,
  ) {
    return this.dashboardService.dashboard(congregationId, cycleId);
  }

  @Get('transactions')
  getTransactions(
    @Query('congregationId') congregationId: string,
    @Query('cycleId') cycleId?: string,
  ) {
    return this.dashboardService.transactions(congregationId, cycleId);
  }

  @Get('accountability-cycles')
  listAccountabilityCycles(@Query('congregationId') congregationId: string) {
    return this.dashboardService.listCycles(congregationId);
  }

  @Get('members')
  getMembers(@Query('congregationId') congregationId: string) {
    return this.dashboardService.members(congregationId);
  }

  @Post('members')
  createMember(@Body() dto: CreateMemberDto) {
    return this.dashboardService.createMember(dto);
  }

  @Get('history')
  getHistory(@Query('congregationId') congregationId: string) {
    return this.dashboardService.history(congregationId);
  }

  @Get('tithe-distribution')
  getTitheDistribution(@Query('congregationId') congregationId: string) {
    return this.dashboardService.titheDistribution(congregationId);
  }

  @Get('monthly-report')
  getMonthlyReport(
    @Query('congregationId') congregationId: string,
    @Query('startDate') startDate: string,
    @Query('endDate') endDate: string,
  ) {
    return this.dashboardService.monthlyReport(congregationId, startDate, endDate);
  }

  @Post('closures')
  createClosure(@Body() dto: CreateClosureDto) {
    return this.dashboardService.createClosure(dto);
  }

  @Get('closures')
  listClosures(@Query('congregationId') congregationId: string) {
    return this.dashboardService.listClosures(congregationId);
  }

  @Get('closures/:closureId/preview')
  previewClosure(
    @Param('closureId') closureId: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.dashboardService.previewClosure(closureId, endDate);
  }

  @Post('closures/:closureId/close')
  closeClosure(
    @Param('closureId') closureId: string,
    @Body() dto: CloseClosureDto,
  ) {
    return this.dashboardService.closeClosure(closureId, dto);
  }

  @Post('tithe-distribution')
  setTitheDistribution(
    @Query('congregationId') congregationId: string,
    @Body() dto: SetTitheDistributionDto,
  ) {
    return this.dashboardService.setTitheDistribution(
      congregationId,
      dto.leaderPercentage,
    );
  }

  @Post('cycles')
  createCycle(@Body() dto: CreateCycleDto) {
    return this.financeService.createCycle(dto);
  }

  @Get('cycles')
  listCycles(@Query('congregationId') congregationId: string) {
    return this.financeService.listCycles(congregationId);
  }

  @Post('entries')
  createEntry(@Body() dto: CreateEntryDto) {
    return this.financeService.createEntry(dto);
  }

  @Get('entries')
  listEntries(
    @Query('congregationId') congregationId: string,
    @Query('cycleId') cycleId?: string,
  ) {
    return this.financeService.listEntries(congregationId, cycleId);
  }

  @Post('payables')
  createPayable(@Body() dto: CreatePayableDto) {
    return this.financeService.createPayable(dto);
  }

  @Get('payables')
  listPayables(@Query('congregationId') congregationId: string) {
    return this.financeService.listPayables(congregationId);
  }

  @Post('payables/:payableId/payments')
  registerPayablePayment(
    @Query('congregationId') congregationId: string,
    @Param('payableId') payableId: string,
    @Body() dto: CreatePayablePaymentDto,
  ) {
    return this.financeService.registerPayablePayment(congregationId, payableId, dto);
  }

  @Get('payables/:payableId/payments')
  listPayablePayments(
    @Query('congregationId') congregationId: string,
    @Param('payableId') payableId: string,
  ) {
    return this.financeService.listPayablePayments(congregationId, payableId);
  }

  @Post('notification-preferences/due-date')
  setNotificationDays(
    @Query('congregationId') congregationId: string,
    @Body() dto: SetNotificationDaysDto,
  ) {
    return this.financeService.setNotificationDays(congregationId, dto.days);
  }

  @Get('cycles/:cycleId/balance')
  getBalance(@Query('congregationId') congregationId: string, @Param('cycleId') cycleId: string) {
    return {
      congregationId,
      cycleId,
      balance: this.financeService.getBalance(congregationId, cycleId),
    };
  }

  @Get('cycles/:cycleId/balance/by-revenue-type')
  getBalanceByRevenueType(
    @Query('congregationId') congregationId: string,
    @Param('cycleId') cycleId: string,
  ) {
    return this.financeService.getBalanceByRevenueType(congregationId, cycleId);
  }

  @Get('cycles/:cycleId/balance/by-revenue-category')
  getBalanceByRevenueCategory(
    @Query('congregationId') congregationId: string,
    @Param('cycleId') cycleId: string,
  ) {
    return this.financeService.getBalanceByRevenueCategory(congregationId, cycleId);
  }
}
