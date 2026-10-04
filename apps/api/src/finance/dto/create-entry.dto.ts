import {
  IsDateString,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class CreateEntryDto {
  @IsUUID()
  congregationId!: string;

  @IsUUID()
  cycleId!: string;

  @IsUUID()
  entryTypeId!: string;

  @IsOptional()
  @IsUUID()
  revenueCategoryId?: string;

  @IsDateString()
  entryDate!: string;

  @IsString()
  description!: string;

  @IsNumber()
  @Min(0.01)
  totalAmount!: number;

  @IsObject()
  paymentLines!: Record<string, number>;
}
