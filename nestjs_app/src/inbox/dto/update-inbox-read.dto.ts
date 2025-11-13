import { IsBoolean } from "class-validator";

export class UpdateInboxReadDto {
  @IsBoolean()
  isRead!: boolean;
}
