import { IsNumber, Max, Min } from 'class-validator';

export class SetTitheDistributionDto {
  @IsNumber()
  @Min(0)
  @Max(100)
  leaderPercentage!: number;
}
