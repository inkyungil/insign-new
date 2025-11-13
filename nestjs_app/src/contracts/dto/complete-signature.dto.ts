import { IsIn, IsNotEmpty, IsObject, IsOptional, IsString } from "class-validator";

export class CompleteSignatureDto {
  @IsString()
  @IsNotEmpty()
  imageData!: string;

  @IsString()
  @IsOptional()
  @IsIn(["draw", "upload"])
  source?: "draw" | "upload";

  @IsObject()
  @IsOptional()
  recipientFormValues?: Record<string, unknown>;
}
