export type TemplateFieldType =
  | "text"
  | "textarea"
  | "number"
  | "currency"
  | "date"
  | "select"
  | "radio"
  | "checkbox"
  | "signature"
  | "email"
  | "phone";

export type TemplateParticipantRole =
  | "author"
  | "recipient"
  | "witness"
  | "viewer";

export interface TemplateFieldOption {
  label: string;
  value: string;
}

export interface TemplateFieldValidation {
  pattern?: string;
  min?: number;
  max?: number;
  minLength?: number;
  maxLength?: number;
}

export interface TemplateFieldDefinition {
  id: string;
  label: string;
  type: TemplateFieldType;
  required?: boolean;
  role: TemplateParticipantRole | "all";
  placeholder?: string;
  helperText?: string;
  options?: TemplateFieldOption[];
  defaultValue?: string | number | boolean | string[];
  validation?: TemplateFieldValidation;
  readonly?: boolean; // 사용자가 직접 수정할 수 없는 필드 (자동 생성)
}

export interface TemplateFormSection {
  id: string;
  title: string;
  role?: TemplateParticipantRole | "all";
  description?: string;
  fields: TemplateFieldDefinition[];
}

export interface TemplateFormSchema {
  version: number;
  title?: string;
  description?: string;
  sections: TemplateFormSection[];
}

export function isTemplateFormSchema(
  value: unknown,
): value is TemplateFormSchema {
  if (!value || typeof value !== "object") {
    return false;
  }

  const schema = value as TemplateFormSchema;
  if (typeof schema.version !== "number" || !Array.isArray(schema.sections)) {
    return false;
  }

  return schema.sections.every((section) => {
    if (!section || typeof section !== "object") {
      return false;
    }

    if (typeof section.id !== "string" || typeof section.title !== "string") {
      return false;
    }

    if (!Array.isArray(section.fields)) {
      return false;
    }

    return section.fields.every((field) => {
      if (!field || typeof field !== "object") {
        return false;
      }

      if (typeof field.id !== "string" || typeof field.label !== "string") {
        return false;
      }

      if (
        field.role &&
        !["author", "recipient", "witness", "viewer", "all"].includes(
          field.role,
        )
      ) {
        return false;
      }

      return (
        typeof field.type === "string" &&
        [
          "text",
          "textarea",
          "number",
          "currency",
          "date",
          "select",
          "radio",
          "checkbox",
          "signature",
          "email",
          "phone",
        ].includes(field.type)
      );
    });
  });
}
