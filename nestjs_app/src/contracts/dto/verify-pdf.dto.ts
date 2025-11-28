import { IsNotEmpty, IsString } from "class-validator";

export class VerifyPdfDto {
  @IsString()
  @IsNotEmpty()
  fileBase64!: string;
}
