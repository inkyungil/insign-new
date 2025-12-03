import { IsIn, IsNotEmpty, IsString, MaxLength } from "class-validator";
import { Transform } from "class-transformer";

export class SendPushMessageDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(["general", "contract"])
  category!: "general" | "contract";

  @Transform(({ value }) => value?.trim())
  @IsString()
  @IsNotEmpty({ message: "제목을 입력해 주세요." })
  @MaxLength(120)
  title!: string;

  @Transform(({ value }) => value?.trim())
  @IsString()
  @IsNotEmpty({ message: "메시지를 입력해 주세요." })
  @MaxLength(500)
  body!: string;
}
