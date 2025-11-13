import { Type } from "class-transformer";
import {
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsNumberString,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from "class-validator";

class ContractPartiesDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  performerName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(190)
  performerEmail?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  performerContact?: string | null;
}

export class CreateContractDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  name!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  templateId?: number;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  clientName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  clientContact?: string;

  @IsOptional()
  @IsString()
  @MaxLength(190)
  clientEmail?: string;

  @ValidateNested()
  @Type(() => ContractPartiesDto)
  performer!: ContractPartiesDto;

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsNumberString()
  amount?: string;

  @IsOptional()
  @IsString()
  details?: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
