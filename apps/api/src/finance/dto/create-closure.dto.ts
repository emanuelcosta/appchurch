import { IsDateString, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateClosureDto {
  @IsUUID()
  congregationId!: string;

  @IsDateString()
  periodStart!: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
