import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Min,
} from 'class-validator';

const ADDRESS_REGEX = /^0x[a-fA-F0-9]{40}$/;
const PRIVATE_KEY_REGEX = /^0x[a-fA-F0-9]{64}$/;

export class KaiaAddressPayloadDto {
  @IsString()
  @Matches(ADDRESS_REGEX, { message: 'from must be a valid 0x-prefixed address' })
  readonly from!: string;
}

export class KaiaBalanceRequestDto extends KaiaAddressPayloadDto {}

export class KaiaApprovalStateDto extends KaiaAddressPayloadDto {}

export class KaiaSetApprovalForAllDto extends KaiaAddressPayloadDto {
  @IsString()
  @Matches(PRIVATE_KEY_REGEX, { message: 'pkey must be a 64-byte hex private key' })
  readonly pkey!: string;
}

export class KaiaMintNftDto {
  @IsString()
  @IsNotEmpty()
  readonly metadata_uri!: string;

  @IsOptional()
  @IsString()
  @Matches(ADDRESS_REGEX, { message: 'recipient must be a valid 0x-prefixed address' })
  readonly recipient?: string;
}

export class KaiaTokenActionDto extends KaiaSetApprovalForAllDto {
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly tokenId!: number;
}

export class KaiaOnSaleDto extends KaiaTokenActionDto {
  @IsString()
  @IsNotEmpty()
  readonly price!: string;
}

export class KaiaBuyNftDto extends KaiaOnSaleDto {}

export class KaiaBurnNftDto extends KaiaTokenActionDto {}

export class KaiaMyNftDto extends KaiaAddressPayloadDto {}

export class KaiaNftDetailDto {
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly tokenId!: number;
}

export class KaiaOnSaleListDto {
  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => {
    if (typeof value === 'boolean') return value;
    if (value === undefined || value === null) return undefined;
    return value === 'true' || value === '1';
  })
  readonly sfl?: boolean;

  @IsOptional()
  @Transform(({ value }) => (value === undefined ? undefined : String(value)))
  readonly stx?: string;
}

export class KaiaTradeRecordMyDto extends KaiaSetApprovalForAllDto {
  @IsString()
  @IsNotEmpty()
  readonly symbol!: string;

  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly sideValue!: number;

  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly currencyValue!: number;

  @IsOptional()
  @Transform(({ value }) => (value === undefined ? undefined : String(value)))
  readonly quantityRaw?: string;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly quantityDecimals?: number;

  @IsOptional()
  @Transform(({ value }) => (value === undefined ? undefined : String(value)))
  readonly priceRaw?: string;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly priceDecimals?: number;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly quantity?: number;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly price?: number;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly timestamp?: number;

  @IsOptional()
  @IsString()
  readonly receiptURI?: string;
}

export class KaiaTradeRecordForDto {
  @IsString()
  @Matches(ADDRESS_REGEX)
  readonly ownerFrom!: string;

  @IsString()
  @Matches(PRIVATE_KEY_REGEX)
  readonly ownerPkey!: string;

  @IsString()
  @Matches(ADDRESS_REGEX)
  readonly trader!: string;

  @IsString()
  @IsNotEmpty()
  readonly symbol!: string;

  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly sideValue!: number;

  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly currencyValue!: number;

  @Transform(({ value }) => String(value))
  @IsNotEmpty()
  readonly quantity!: string;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly quantityDecimals?: number;

  @Transform(({ value }) => String(value))
  @IsNotEmpty()
  readonly price!: string;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly priceDecimals?: number;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly timestamp?: number;

  @IsOptional()
  @IsString()
  readonly receiptURI?: string;
}

export class KaiaTradeGetDto {
  @Transform(({ value }) => String(value))
  @IsNotEmpty()
  readonly id!: string;
}

export class KaiaTradeListByTraderDto {
  @IsString()
  @Matches(ADDRESS_REGEX)
  readonly trader!: string;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(0)
  readonly start?: number;

  @IsOptional()
  @Transform(({ value }) => (typeof value === 'string' ? Number(value) : value))
  @IsInt()
  @Min(1)
  readonly count?: number;
}

export class KaiaTradeTradesOfDto {
  @IsString()
  @Matches(ADDRESS_REGEX)
  readonly trader!: string;
}

export class KaiaTradeSetReceiptUriDto extends KaiaSetApprovalForAllDto {
  @Transform(({ value }) => String(value))
  @IsNotEmpty()
  readonly tradeId!: string;

  @IsString()
  @IsOptional()
  readonly receiptURI?: string;
}
