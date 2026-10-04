import { IsDateString, IsOptional, IsString } from 'class-validator';

export class CloseClosureDto {
  @IsDateString()
  periodEnd!: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
