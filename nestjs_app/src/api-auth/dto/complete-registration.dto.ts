import { IsBoolean } from "class-validator";

export class CompleteRegistrationDto {
  @IsBoolean()
  agreedToTerms!: boolean;

  @IsBoolean()
  agreedToPrivacy!: boolean;

  @IsBoolean()
  agreedToSensitive!: boolean;

  @IsBoolean()
  agreedToMarketing!: boolean;
}
