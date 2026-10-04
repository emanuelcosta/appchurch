import { IsIn, IsInt, IsString, IsUUID, Max, Min } from 'class-validator';

export class CreateUploadSignatureDto {
  @IsUUID()
  entityId!: string;

  @IsString()
  fileName!: string;

  @IsIn(['image/jpeg', 'image/png', 'application/pdf'])
  mimeType!: string;

  @IsInt()
  @Min(1)
  @Max(10 * 1024 * 1024)
  bytes!: number;
}
