import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { ContractMailLog } from "./contract-mail-log.entity";
import { OneToMany } from "typeorm";

@Entity({ name: "contracts" })
export class Contract {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: "template_id", type: "int", nullable: true })
  templateId!: number | null;

  @Column({ type: "varchar", length: 200 })
  name!: string;

  @Column({ name: "client_name", type: "varchar", length: 120 })
  clientName!: string;

  @Column({
    name: "client_contact",
    type: "varchar",
    length: 255,
    nullable: true,
  })
  clientContact!: string | null;

  @Column({
    name: "client_email",
    type: "varchar",
    length: 255,
    nullable: true,
  })
  clientEmail!: string | null;

  @Column({
    name: "performer_name",
    type: "varchar",
    length: 120,
    nullable: true,
  })
  performerName!: string | null;

  @Column({
    name: "performer_email",
    type: "varchar",
    length: 255,
    nullable: true,
  })
  performerEmail!: string | null;

  @Column({
    name: "performer_contact",
    type: "varchar",
    length: 255,
    nullable: true,
  })
  performerContact!: string | null;

  @Column({ name: "start_date", type: "date", nullable: true })
  startDate!: Date | null;

  @Column({ name: "end_date", type: "date", nullable: true })
  endDate!: Date | null;

  @Column({
    name: "amount",
    type: "decimal",
    precision: 18,
    scale: 2,
    nullable: true,
  })
  amount!: string | null;

  @Column({ type: "text", nullable: true })
  details!: string | null;

  @Column({ type: "longtext", nullable: true })
  metadata!: Record<string, unknown> | string | null;

  @Column({ name: "created_by_user_id", type: "int", nullable: true })
  createdByUserId!: number | null;

  @Column({
    name: "signature_token",
    type: "varchar",
    length: 128,
    nullable: true,
    unique: true,
  })
  signatureToken!: string | null;

  @Column({
    name: "signature_token_expires_at",
    type: "datetime",
    nullable: true,
  })
  signatureTokenExpiresAt!: Date | null;

  @Column({ name: "signature_sent_at", type: "datetime", nullable: true })
  signatureSentAt!: Date | null;

  @Column({ name: "signature_declined_at", type: "datetime", nullable: true })
  signatureDeclinedAt!: Date | null;

  @Column({ name: "signature_completed_at", type: "datetime", nullable: true })
  signatureCompletedAt!: Date | null;

  @Column({ name: "signature_image", type: "longtext", nullable: true })
  signatureImage!: string | null;

  @Column({
    name: "signature_source",
    type: "varchar",
    length: 30,
    nullable: true,
  })
  signatureSource!: string | null;

  @Column({ name: "status", type: "varchar", length: 60, default: "draft" })
  status!: string;

  @CreateDateColumn({ name: "created_at" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt!: Date;

  @OneToMany(() => ContractMailLog, (mailLog) => mailLog.contract)
  mailLogs!: ContractMailLog[];
}
