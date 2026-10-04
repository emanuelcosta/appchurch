import { Controller, Get, Headers } from '@nestjs/common';
import { SupabaseDashboardService } from './supabase-dashboard.service';

@Controller('me')
export class MeController {
  constructor(private readonly dashboardService: SupabaseDashboardService) {}

  @Get()
  getMe(@Headers('authorization') authorization?: string) {
    return this.dashboardService.me(authorization);
  }
}
