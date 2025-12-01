import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { TemplateFormSchema } from "./template-form.types";

@Entity({ name: "templates" })
export class Template {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: "varchar", length: 160 })
  name!: string;

  @Column({ type: "varchar", length: 80 })
  category!: string;

  @Column({ type: "text" })
  description!: string;

  @Column({ type: "text", nullable: true })
  content!: string | null;

  @Column({ name: "file_path", type: "varchar", length: 500, nullable: true })
  filePath!: string | null;

  @Column({ name: "file_name", type: "varchar", length: 255, nullable: true })
  fileName!: string | null;

  @Column({ name: "original_file_name", type: "varchar", length: 255, nullable: true })
  originalFileName!: string | null;

  @Column({ name: "last_updated_at", type: "datetime", nullable: true })
  lastUpdatedAt!: Date | null;

  @Column({ name: "form_schema", type: "json", nullable: true })
  formSchema!: TemplateFormSchema | null;

  @Column({ name: "sample_payload", type: "json", nullable: true })
  samplePayload!: Record<string, unknown> | null;

  @Column({ name: "is_active", type: "boolean", default: true })
  isActive!: boolean;

  @CreateDateColumn({ name: "created_at" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt!: Date;
}
