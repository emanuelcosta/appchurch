import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/** Campos da ficha de membro (mesmas colunas da planilha membros.xlsx). */
export class CreateMemberDto {
  /** Gerado no app: reenviar o mesmo cadastro (sincronização offline) não duplica. */
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsUUID()
  congregationId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  fullName!: string;

  @IsOptional()
  @IsDateString()
  birthDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  rg?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  cpf?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  maritalStatus?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  motherName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  fatherName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  spouseName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  nationality?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  birthplace?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  ministryRole?: string;

  @IsOptional()
  @IsDateString()
  ministryRoleSince?: string;

  @IsOptional()
  @IsBoolean()
  holySpiritBaptism?: boolean;

  @IsOptional()
  @IsDateString()
  holySpiritBaptismDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  education?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(50)
  childrenCount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  phone?: string;

  @IsOptional()
  @IsEmail()
  email?: string;
}
