import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsNumber,
  IsObject,
  IsPositive,
  IsUUID,
} from 'class-validator';

/** Pagamento (total ou parcial) de uma conta a pagar, com as fontes do dinheiro. */
export class PayPayableDto {
  /** Gerado no app: reenviar o mesmo pagamento (fila offline) não duplica. */
  @IsUUID()
  paymentId!: string;

  @IsUUID()
  congregationId!: string;

  @IsDateString()
  paymentDate!: string;

  @IsIn(['CASH', 'PIX'])
  paymentMethod!: 'CASH' | 'PIX';

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount!: number;

  @IsObject()
  fundingSources!: Record<string, number>;
}
