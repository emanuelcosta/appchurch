import { IsInt, IsObject, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class PushOperationDto {
  @IsUUID()
  operationId!: string;

  @IsUUID()
  idempotencyKey!: string;

  @IsUUID()
  scopeId!: string;

  @IsString()
  operationType!: string;

  @IsString()
  entityType!: string;

  @IsUUID()
  entityId!: string;

  @IsObject()
  payload!: Record<string, unknown>;

  @IsOptional()
  @IsUUID()
  dependsOn?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  baseVersion?: number;
}
