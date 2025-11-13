import { IsIn, IsNotEmpty, IsString, MaxLength } from "class-validator";

export class SendPushMessageDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(["general", "contract"])
  category!: "general" | "contract";

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  body!: string;
}
