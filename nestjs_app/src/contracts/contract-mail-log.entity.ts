import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from "typeorm";
import { Contract } from "./contract.entity";

@Entity({ name: "contract_mail_logs" })
export class ContractMailLog {
  @PrimaryGeneratedColumn()
  id!: number;

  @ManyToOne(() => Contract, (contract) => contract.mailLogs, {
    onDelete: "CASCADE",
  })
  @JoinColumn({ name: "contract_id" })
  contract!: Contract;

  @Column({ name: "contract_id", type: "int" })
  contractId!: number;

  @Column({ name: "recipient_email", type: "varchar", length: 255 })
  recipientEmail!: string;

  @Column({ name: "mail_type", type: "varchar", length: 60 })
  mailType!: string;

  @Column({ name: "status", type: "varchar", length: 30 })
  status!: string;

  @Column({ name: "error_message", type: "text", nullable: true })
  errorMessage!: string | null;

  @CreateDateColumn({ name: "created_at" })
  createdAt!: Date;
}
