import { IsEnum, IsOptional, IsString } from "class-validator";
import { InquiryStatus } from "../inquiry.entity";

export class UpdateInquiryStatusDto {
  @IsEnum(InquiryStatus)
  @IsOptional()
  status?: InquiryStatus;

  @IsString()
  @IsOptional()
  adminNote?: string;
}
