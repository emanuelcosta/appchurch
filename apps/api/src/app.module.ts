import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthController } from './health.controller';
import { SyncModule } from './sync/sync.module';
import { FinanceModule } from './finance/finance.module';
import { AttachmentsModule } from './attachments/attachments.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', '../../.env'],
    }),
    SyncModule,
    FinanceModule,
    AttachmentsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
