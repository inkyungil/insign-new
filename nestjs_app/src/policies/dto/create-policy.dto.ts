import { IsEnum, IsString, IsOptional, IsBoolean } from "class-validator";
import { Transform } from "class-transformer";

export enum PolicyType {
  PRIVACY_POLICY = "privacy_policy",
  TERMS_OF_SERVICE = "terms_of_service",
}

export class CreatePolicyDto {
  @IsEnum(PolicyType)
  type!: PolicyType;

  @IsString()
  title!: string;

  @IsString()
  content!: string;

  @IsOptional()
  @IsString()
  version?: string;

  @IsOptional()
  @Transform(({ value }) => {
    if (typeof value === "boolean") {
      return value;
    }
    if (typeof value === "number") {
      return value === 1;
    }
    if (typeof value === "string") {
      const normalized = value.trim().toLowerCase();
      if (["true", "1", "on", "yes"].includes(normalized)) {
        return true;
      }
      if (["false", "0", "off", "no", ""].includes(normalized)) {
        return false;
      }
    }
    return undefined;
  })
  @IsBoolean()
  isActive?: boolean;
}
