import { IsString, IsUUID, Length } from 'class-validator';

export class CreateExpenseCategoryDto {
  @IsUUID()
  congregationId!: string;

  @IsString()
  @Length(2, 80)
  name!: string;
}
