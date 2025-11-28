import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class AdminUpdatePlanDto {
  @IsOptional()
  @IsString()
  @MaxLength(20)
  tier?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @Transform(({ value }) => (value === '' || value === undefined ? undefined : Number(value)))
  @IsInt()
  monthlyContractLimit?: number;

  @IsOptional()
  @Transform(({ value }) => (value === '' || value === undefined ? undefined : Number(value)))
  @IsInt()
  monthlyPointsLimit?: number;

  @IsOptional()
  @Transform(({ value }) => (value === '' || value === undefined ? undefined : Number(value)))
  @IsInt()
  initialPoints?: number;

  @IsOptional()
  @Transform(({ value }) => (value === '' || value === undefined ? undefined : Number(value)))
  @IsInt()
  @Min(0)
  priceMonthly?: number;

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
  @Transform(({ value }) => (value === '' || value === undefined ? undefined : Number(value)))
  @IsInt()
  displayOrder?: number;
}
