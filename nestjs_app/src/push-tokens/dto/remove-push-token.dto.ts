import { IsNotEmpty, IsString, MaxLength } from "class-validator";

export class RemovePushTokenDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  token!: string;
}
