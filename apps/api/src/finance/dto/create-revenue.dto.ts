import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Lançamento de receita (oferta de culto, oferta alçada ou dízimo), com o
 * valor recebido em PIX e em dinheiro, como as colunas da planilha.
 */
export class CreateRevenueDto {
  /** Gerado no app: reenviar o mesmo lançamento (fila offline) não duplica. */
  @IsUUID()
  id!: string;

  @IsUUID()
  congregationId!: string;

  @IsIn(['OFERTAS_CULTO', 'OFERTAS_ALCADAS', 'DIZIMOS'])
  fundCode!: 'OFERTAS_CULTO' | 'OFERTAS_ALCADAS' | 'DIZIMOS';

  /** Tipo cadastrado do fundo (ex.: Bazar em ofertas alçadas). */
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsDateString()
  date!: string;

  /** Descrição do culto ou nome de quem contribuiu. */
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  description!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  pixAmount!: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  cashAmount!: number;
}
