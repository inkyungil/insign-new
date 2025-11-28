import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { SubscriptionStatus } from '../entities/user-subscription.entity';

export class AdminCreateSubscriptionDto {
  @IsInt()
  @Type(() => Number)
  @Min(1)
  userId!: number;

  @IsInt()
  @Type(() => Number)
  @Min(1)
  planId!: number;

  @IsString()
  @IsNotEmpty()
  startedAt!: string;

  @IsOptional()
  @IsString()
  expiresAt?: string;

  @IsOptional()
  @IsEnum(SubscriptionStatus)
  status?: SubscriptionStatus;

  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => value === true || value === 'true' || value === '1' || value === 'on')
  autoRenew?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  paymentMethod?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  paymentId?: string;

  @IsOptional()
  @Transform(({ value }) => (value === '' || value === null || value === undefined ? undefined : Number(value)))
  @Type(() => Number)
  @IsInt()
  amountPaid?: number;

}
