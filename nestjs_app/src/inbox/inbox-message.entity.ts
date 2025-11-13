import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { User } from "../users/user.entity";

export type InboxMessageKind = "notice" | "alert" | "news" | "report" | "system";

@Entity({ name: "inbox_messages" })
export class InboxMessage {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: "user_id", type: "int" })
  userId!: number;

  @ManyToOne(() => User, { onDelete: "CASCADE" })
  @JoinColumn({ name: "user_id" })
  user?: User;

  @Column({ type: "varchar", length: 24 })
  kind!: InboxMessageKind;

  @Column({ type: "varchar", length: 190 })
  title!: string;

  @Column({ type: "text" })
  body!: string;

  @Column({ type: "json", nullable: true })
  tags!: string[] | null;

  @Column({ name: "is_read", type: "tinyint", default: false })
  isRead!: boolean;

  @Column({ name: "read_at", type: "datetime", nullable: true })
  readAt!: Date | null;

  @Column({ type: "json", nullable: true })
  metadata!: Record<string, unknown> | null;

  @CreateDateColumn({ name: "created_at" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt!: Date;
}
