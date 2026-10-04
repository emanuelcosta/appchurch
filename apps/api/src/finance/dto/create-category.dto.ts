import { IsIn, IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

/** Cadastro de tipo de receita (com o fundo) ou de categoria de despesa. */
export class CreateCategoryDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsUUID()
  congregationId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  name!: string;

  /** Obrigatório para tipo de receita. */
  @IsOptional()
  @IsIn(['OFERTAS_CULTO', 'OFERTAS_ALCADAS', 'DIZIMOS'])
  fundCode?: string;
}
