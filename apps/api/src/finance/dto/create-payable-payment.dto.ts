import { IsDateString, IsNumber, IsObject, IsString, Min } from 'class-validator';

export class CreatePayablePaymentDto {
  @IsDateString()
  paymentDate!: string;

  @IsNumber()
  @Min(0.01)
  amount!: number;

  @IsString()
  paymentMethod!: 'CASH' | 'PIX';

  @IsObject()
  fundingSources!: Record<string, number>;
}
