import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { PushOperationDto } from './dto/push-operation.dto';
import { ResolveConflictDto } from './dto/resolve-conflict.dto';
import { PullOperationsQuery } from './dto/pull-operations.query';
import { SyncService } from './sync.service';

@Controller('sync')
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Post('push')
  push(@Body() operation: PushOperationDto) {
    return this.syncService.push(operation);
  }

  @Get('pull')
  pull(@Query() query: PullOperationsQuery) {
    return this.syncService.pull(query.scopeId, query.cursor);
  }

  @Post('resolve-conflict')
  resolveConflict(@Body() operation: ResolveConflictDto) {
    return this.syncService.resolveConflict(operation);
  }
}
