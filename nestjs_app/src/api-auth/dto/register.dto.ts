import { IsOptional, IsString, MaxLength } from "class-validator";
import { LoginDto } from "./login.dto";

export class RegisterDto extends LoginDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  displayName?: string;
}
