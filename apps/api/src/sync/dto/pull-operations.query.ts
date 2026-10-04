import { Type } from 'class-transformer';
import { IsInt, IsUUID, Min } from 'class-validator';

export class PullOperationsQuery {
  @IsUUID()
  scopeId!: string;

  @IsInt()
  @Min(0)
  @Type(() => Number)
  cursor = 0;
}
