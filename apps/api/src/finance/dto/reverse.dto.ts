import { IsBoolean, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

/** Estorno/cancelamento de lançamento: o motivo fica na auditoria. */
export class ReverseDto {
  @IsUUID()
  congregationId!: string;

  @IsString()
  @MinLength(3, { message: 'Informe o motivo (mínimo 3 letras).' })
  @MaxLength(300)
  reason!: string;

  /**
   * Estorno de pagamento: `true` cancela a despesa inteira; `false` mantém
   * a conta em aberto (o pagamento não aconteceu, mas a conta existe).
   */
  @IsOptional()
  @IsBoolean()
  cancelExpense?: boolean;
}
