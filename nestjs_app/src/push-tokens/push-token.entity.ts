import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { User } from "../users/user.entity";

@Entity({ name: "user_push_tokens" })
@Index(["token"], { unique: true })
@Index(["userId", "token"], { unique: true })
export class UserPushToken {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: "user_id", type: "int", unsigned: true })
  userId!: number;

  @ManyToOne(() => User, { onDelete: "CASCADE" })
  @JoinColumn({ name: "user_id" })
  user!: User;

  @Column({ type: "varchar", length: 255 })
  token!: string;

  @Column({ type: "varchar", length: 20, nullable: true })
  platform?: string | null;

  @Column({ name: "last_seen_at", type: "datetime", nullable: true })
  lastSeenAt?: Date | null;

  @CreateDateColumn({ name: "created_at" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt!: Date;
}
