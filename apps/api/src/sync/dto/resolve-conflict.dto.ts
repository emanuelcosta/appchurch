import { IsIn, IsObject, IsString, IsUUID } from 'class-validator';

export class ResolveConflictDto {
  @IsUUID()
  operationId!: string;

  @IsUUID()
  scopeId!: string;

  @IsIn(['RETRY', 'DISCARD', 'CREATE_ADJUSTMENT'])
  resolution!: 'RETRY' | 'DISCARD' | 'CREATE_ADJUSTMENT';

  @IsObject()
  payload!: Record<string, unknown>;

  @IsString()
  reason!: string;
}
