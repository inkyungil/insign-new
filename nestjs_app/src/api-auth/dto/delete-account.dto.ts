import { IsOptional, IsString, MaxLength } from "class-validator";

export class DeleteAccountDto {
  @IsOptional()
  @IsString()
  @MaxLength(128)
  password?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  reason?: string;
}
