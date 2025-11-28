import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class AdminCreatePlanDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  tier!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  name!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsInt()
  @Transform(({ value }) => Number(value))
  monthlyContractLimit!: number;

  @IsInt()
  @Transform(({ value }) => Number(value))
  monthlyPointsLimit!: number;

  @IsInt()
  @Transform(({ value }) => Number(value))
  initialPoints!: number;

  @IsInt()
  @Min(0)
  @Transform(({ value }) => Number(value))
  priceMonthly!: number;

  @IsOptional()
  @Transform(({ value }) =>
    value === undefined || value === null || value === '' ? null : Number(value),
  )
  priceYearly?: number | null;

  @IsOptional()
  @IsString()
  features?: string;

  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => value === 'on' || value === true || value === 'true' || value === '1')
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  @Transform(({ value }) => Number(value))
  displayOrder?: number;
}
