import { IsNotEmpty, IsString } from "class-validator";

export class SendInquiryResponseDto {
  @IsString()
  @IsNotEmpty()
  message!: string;
}
