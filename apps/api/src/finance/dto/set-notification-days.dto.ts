import { IsInt, Max, Min } from 'class-validator';

export class SetNotificationDaysDto {
  @IsInt()
  @Min(0)
  @Max(365)
  days!: number;
}
