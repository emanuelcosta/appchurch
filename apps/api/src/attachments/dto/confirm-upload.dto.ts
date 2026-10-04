import { IsIn, IsInt, IsString, IsUUID, Max, Min } from 'class-validator';

export class ConfirmUploadDto {
  @IsUUID()
  entityId!: string;

  @IsString()
  publicId!: string;

  @IsIn(['image', 'raw'])
  resourceType!: 'image' | 'raw';

  @IsString()
  format!: string;

  @IsInt()
  @Min(1)
  @Max(10 * 1024 * 1024)
  bytes!: number;
}
