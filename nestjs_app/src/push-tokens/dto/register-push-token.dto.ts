import { IsIn, IsNotEmpty, IsOptional, IsString, MaxLength } from "class-validator";

const allowedPlatforms = [
  "android",
  "ios",
  "macos",
  "windows",
  "linux",
  "fuchsia",
];

export class RegisterPushTokenDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  token!: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  @IsIn(allowedPlatforms, {
    message: `platform must be one of: ${allowedPlatforms.join(", ")}`,
  })
  platform?: string;
}
