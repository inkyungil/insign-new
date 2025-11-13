import {
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from "class-validator";
import { Type } from "class-transformer";
import { InboxMessageKind } from "../inbox-message.entity";

class MessageMetadataDto {
  [key: string]: unknown;
}

export class CreateInboxMessageDto {
  @IsEnum(["notice", "alert", "news", "report", "system"], {
    message: "지원하지 않는 메시지 유형입니다.",
  })
  kind!: InboxMessageKind;

  @IsString()
  @IsNotEmpty()
  @MaxLength(190)
  title!: string;

  @IsString()
  @IsNotEmpty()
  body!: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @ValidateNested()
  @Type(() => MessageMetadataDto)
  metadata?: Record<string, unknown> | null;
}
