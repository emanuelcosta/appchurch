import { Module } from '@nestjs/common';
import { FinanceController } from './finance.controller';
import { FinanceService } from './finance.service';
import { LedgerController } from './ledger.controller';
import { LedgerService } from './ledger.service';
import { MeController } from './me.controller';
import { SupabaseDashboardService } from './supabase-dashboard.service';
import { SupabaseRestService } from './supabase-rest.service';

@Module({
  controllers: [FinanceController, LedgerController, MeController],
  providers: [FinanceService, SupabaseDashboardService, SupabaseRestService, LedgerService],
})
export class FinanceModule {}
