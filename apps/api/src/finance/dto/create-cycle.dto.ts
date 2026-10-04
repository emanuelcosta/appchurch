import { IsDateString, IsNumber, IsString, Min } from 'class-validator';

export class CreateCycleDto {
  @IsString()
  congregationId!: string;

  @IsString()
  name!: string;

  @IsDateString()
  startDate!: string;

  @IsDateString()
  endDate!: string;

  @IsNumber()
  @Min(0)
  openingBalance = 0;
}
