import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsObject,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';

/**
 * Lançamento de despesa: paga agora (com as fontes do dinheiro) ou
 * conta a pagar (fontes definidas no pagamento).
 */
export class CreateExpenseDto {
  /** Gerado no app: reenviar a mesma despesa (sincronização offline) não duplica. */
  @IsUUID()
  id!: string;

  @IsUUID()
  congregationId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  description!: string;

  @IsUUID()
  categoryId!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount!: number;

  @IsIn(['PAID', 'PAYABLE'])
  status!: 'PAID' | 'PAYABLE';

  /** Despesa paga: data, forma e fontes (soma igual ao valor). */
  @ValidateIf((dto: CreateExpenseDto) => dto.status === 'PAID')
  @IsDateString()
  paymentDate?: string;

  @ValidateIf((dto: CreateExpenseDto) => dto.status === 'PAID')
  @IsIn(['CASH', 'PIX'])
  paymentMethod?: 'CASH' | 'PIX';

  @ValidateIf((dto: CreateExpenseDto) => dto.status === 'PAID')
  @IsObject()
  fundingSources?: Record<string, number>;

  /** Conta a pagar: vencimento e aviso. */
  @ValidateIf((dto: CreateExpenseDto) => dto.status === 'PAYABLE')
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(365)
  notificationDaysBefore?: number;
}
