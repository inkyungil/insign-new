import { IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from "class-validator";
import { InquiryCategory } from "../inquiry.entity";

export class CreateInquiryDto {
  @IsEnum(InquiryCategory)
  @IsNotEmpty()
  category!: InquiryCategory;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  subject!: string;

  @IsString()
  @IsNotEmpty()
  content!: string;

  @IsOptional()
  @IsString({ each: true })
  attachmentUrls?: string[];
}
