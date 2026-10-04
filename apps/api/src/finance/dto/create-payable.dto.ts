import {
  IsDateString,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class CreatePayableDto {
  @IsUUID()
  congregationId!: string;

  @IsUUID()
  cycleId!: string;

  @IsUUID()
  categoryId!: string;

  @IsObject()
  fundingSources!: Record<string, number>;

  @IsString()
  description!: string;

  @IsDateString()
  issueDate!: string;

  @IsDateString()
  dueDate!: string;

  @IsNumber()
  @Min(0.01)
  amount!: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  notificationDaysBefore?: number;
}
