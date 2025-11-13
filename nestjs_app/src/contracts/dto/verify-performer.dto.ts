import { IsEmail, IsNotEmpty, IsString } from "class-validator";

export class VerifyPerformerDto {
  @IsString()
  @IsNotEmpty()
  performerName!: string;

  @IsEmail()
  performerEmail!: string;

  @IsString()
  @IsNotEmpty()
  performerContact!: string;
}
