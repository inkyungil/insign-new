import { Template } from "../template.entity";
import { TemplateFormSchema } from "../template-form.types";

const parseJsonColumn = <T>(value: unknown): T | null => {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) {
      return null;
    }

    try {
      return JSON.parse(trimmed) as T;
    } catch {
      return null;
    }
  }

  return value as T;
};

export class TemplateResponseDto {
  id!: number;
  name!: string;
  category!: string;
  description!: string;
  content!: string | null;
  filePath!: string | null;
  fileName!: string | null;
  originalFileName!: string | null;
  lastUpdatedAt!: Date | null;
  formSchema!: TemplateFormSchema | null;
  samplePayload!: Record<string, unknown> | null;

  static fromEntity(entity: Template): TemplateResponseDto {
    const dto = new TemplateResponseDto();
    dto.id = entity.id;
    dto.name = entity.name;
    dto.category = entity.category;
    dto.description = entity.description;
    dto.content = entity.content;
    dto.filePath = entity.filePath;
    dto.fileName = entity.fileName;
    dto.originalFileName = entity.originalFileName;
    dto.lastUpdatedAt = entity.lastUpdatedAt;
    dto.formSchema = parseJsonColumn<TemplateFormSchema>(entity.formSchema);
    dto.samplePayload = parseJsonColumn<Record<string, unknown>>(entity.samplePayload);
    return dto;
  }
}
